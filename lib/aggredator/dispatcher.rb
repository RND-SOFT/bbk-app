require 'aggredator/dispatcher/message'
require 'aggredator/dispatcher/result'
require 'aggredator/dispatcher/route'
require 'aggredator/dispatcher/transformer'
require 'aggredator/dispatcher/undeliverable_error'

module Aggredator
  class Dispatcher
    attr_accessor :queue, :client, :observer, :before_transformers, :domains, :watchdog, :after_transformers
    attr_reader :executor

    def initialize(queue, client, observer, domains, watchdog: nil, executor: Aggredator::Executor::Default.new)
      @queue = queue
      @client = client
      @observer = observer
      @before_transformers = []
      @after_transformers = []
      @domains = domains
      @watchdog = watchdog

      @executor = executor
      @executor.dispatcher = self
    end

    def before(transformer)
      raise TypeError.new("no implicit conversion of #{transformer.class} into #{Transformer.to_s}") unless transformer.is_a? Transformer

      @before_transformers << transformer
    end

    def after(transformer)
      raise TypeError.new("no implicit conversion of #{transformer.class} into #{Transformer.to_s}") unless transformer.is_a? Transformer

      @after_transformers << transformer
    end

    def run(block: true)
      @watchdog.start if @watchdog.present?
      queue.subscribe(block: block, manual_ack: true) do |delivery_info, properties, body|
        mqmsg = { delivery_info: delivery_info, properties: properties, body: body }
        ActiveSupport::Notifications.instrument 'dispatcher.request', msg: mqmsg, queue: queue do
          process_request(mqmsg)
        end
      end
    end

    def process_request(mqmsg)
      delivery_info = mqmsg[:delivery_info]
      properties = mqmsg[:properties]
      body = mqmsg[:body]

      $logger&.debug "Get message: body = #{body.inspect}, properties = #{properties.inspect}."

      msg = transform_incomming(Aggredator::Dispatcher::Message.new(delivery_info, properties, body))

      results = executor.call(msg) do |m|
        process_incomming_message(mqmsg, m)
      end

      send_results(mqmsg, msg, results)
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: mqmsg, exception: e
      client.reject delivery_info.delivery_tag if delivery_info&.delivery_tag
      $logger&.debug e.backtrace
      $logger&.error "Exception on processing message with properties = #{properties.inspect}"
      $logger&.error "Exception info: #{e.inspect}"
    end

    def publish_results(results)
      Concurrent::Promises.zip_futures(*results.map {|result| publish(result) })
    end

    def publish(result)
      route = result.route
      ex = domains[route.domain]

      unless ex
        $logger&.error "Can't publish result: no exchange for domain #{route.domain}. message properties = #{result.message.headers.inspect}"
        raise ArgumentError.new("no exchange for domain #{route.domain}")
      end

      client.publish(route.routing_key, result.message, exchange: ex, opts: result.properties)
    end

    private

      def transform_incomming(msg)
        before_transformers.reduce(msg) do |m, tr|
          tr.call(m)
        end
      end

      def transform_outcoming(res, source_message)
        after_transformers.reduce(res) do |m, tr|
          tr.call(m, source_message)
        end
      end

      def process_incomming_message(mqmsg, incmsg)
        matched, callback = @observer.match(incmsg.properties, incmsg.body, incmsg.delivery_info)

        results = []
        ActiveSupport::Notifications.instrument 'dispatcher.request.process', msg: mqmsg, match: matched do
          watchdog&.touch
          callback.call(incmsg, results: results)
        end

        # Отфильтровываем результаты по типам, для того чтобы корректно обрабатывать сообщения
        # неправильного формата или с отсутствием ответов от процессора.
        [results].flatten.select {|e| e.is_a? Aggredator::Dispatcher::Result }.map {|res| transform_outcoming(res, incmsg) }
      end

      def send_results(mqmsg, incmsg, results)
        results.each do |res_msg|
          res_msg.properties[:message_id] ||= res_msg.message.headers[:message_id] || incmsg.reply_message_id(res_msg.route)
        end

        publish_results(results).then do |_successes|
          client.ack(incmsg.delivery_tag)
        end.rescue do |*errors|
          error = errors.compact.first
          ActiveSupport::Notifications.instrument 'dispatcher.request.result_rejected', msg: mqmsg, message: error.inspect
          $logger&.error "Published result failed: #{error.inspect}"
          client.reject(incmsg.delivery_tag)
        rescue StandardError => e
          STDERR.puts "[CRITICAL] #{self.class} [#{Process.pid}] failure exiting..."
          ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: mqmsg, exception: e
          sleep(10)
          exit!(1)
        end
      end
  end
end