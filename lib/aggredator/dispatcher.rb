require 'aggredator/dispatcher/message'
require 'aggredator/dispatcher/result'
require 'aggredator/dispatcher/route'
require 'aggredator/dispatcher/message_stream'
require 'aggredator/dispatcher/undeliverable_error'
require 'concurrent'

module Aggredator
  class Dispatcher
    attr_reader :consumers, :publishers, :observer, :middlewares, :logger

    POOL_SIZE = 3
    ANSWER_DOMAIN = 'answer'

    def initialize observer, logger: Logger.new(IO::NULL)
      @observer = observer
      @logger = logger
      @consumers = []
      @publishers = []
      @middlewares = []
    end

    def register_consumer(consumer)
      consumers << consumer
    end

    def register_publisher(publisher)
      publishers << publisher
    end

    def register_middleware(middleware)
      middlewares << middleware
    end

    def run
      @stream = MessageStream.new
      @pool = Concurrent::FixedThreadPool.new(POOL_SIZE)
      logger.debug('starting consumers')
      logger.warn("empty consumers list") if consumers.blank?
      consumers.each{|cons| cons.run(@stream)}
      for msg in @stream
        @pool.post do
          process msg
        end
      end
    end

    def close
      @stream.close if @stream.present?
    end

    protected

    def process message
      results = build_processing_stack.call(message).select {|e| e.is_a? Aggredator::Dispatcher::Result}
      send_results(message, results)
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: message, exception: e
      message.consumer.reject(message)
      logger.debug e.backtrace
      logger.error "Exception on processing message with headers = #{message.headers.inspect}"
      logger.error "Exception info: #{e.inspect}"
    end

    def process_message message
      matched, processor = find_processor(message)
      results = []
      begin
        is_unknown = @observer.instance_variable_get('@default') == processor
        ActiveSupport::Notifications.instrument 'dispatcher.request.process', msg: message, match: matched, unknown: is_unknown do
          processor.call(message, results: results)
        end
      rescue => e
        if processor.respond_to?(:on_error)
          results = processor.on_error(message, e)
        else
          raise
        end
      end
      [results].flatten
    rescue => e
      ActiveSupport::Notifications.instrument 'dispatcher.request.exception', msg: message, match: matched, processor: processor, exception: e
      raise
    end

    def find_processor(msg)
      matched, callback = @observer.match(msg.headers, msg.payload, msg.delivery_info)
      return [matched, callback.is_a?(Aggredator::Factory) ? callback.create() : callback]
    end

    def build_processing_stack
      stack = Proc.new{|msg| process_message(msg)}
      middlewares.reduce(stack) do |stack, middleware|
        if middleware.respond_to?(:build)
          middleware.build(stack)
        else
          middleware.new(stack)
        end
      end
    end

    def send_results incoming, results
      answers, results = results.partition {|msg| msg.route.domain == ANSWER_DOMAIN}
      answer = answers.first
      Concurrent::Promises.zip_futures(*results.map{|result| publish_result(result)}).then do |_successes|
        incoming.consumer.ack(incoming, answer: answer)
      end.rescue do |*errors|
        error = errors.compact.first
        ActiveSupport::Notifications.instrument 'dispatcher.request.result_rejected', msg: incoming, message: error.inspect
        logger.error "Published result failed: #{error.inspect}"
        incoming.consumer.nack(incoming)
      rescue StandardError => e
        STDERR.puts "[CRITICAL] #{self.class} [#{Process.pid}] failure exiting..."
        ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: incoming, exception: e
        sleep(10)
        exit!(1)
      end
    end

    # @return [Concurrent::Promises::ResolvableFuture]
    def publish_result result
      route = result.route
      publisher = publishers.find {|pub| pub.protocols.include?(route.scheme)}
      if publisher.nil?
        raise "Not found publisher for scheme #{route.scheme}"
      end
      # return Concurrent::Promises.resolvable_future
      publisher.publish(result)
    end

  end
end