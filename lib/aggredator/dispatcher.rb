require 'aggredator/app/thread_pool'
require 'aggredator/dispatcher/message'
require 'aggredator/dispatcher/result'
require 'aggredator/dispatcher/route'
require 'aggredator/dispatcher/message_stream'
require 'aggredator/dispatcher/pool_proxy_stream'
require 'aggredator/dispatcher/undeliverable_error'
require 'aggredator/dispatcher/queue_stream_strategy'
require 'aggredator/dispatcher/direct_stream_strategy'
require 'aggredator/dispatcher/message_fallback_policies/base'
require 'aggredator/dispatcher/message_fallback_policies/reject'
require 'aggredator/dispatcher/message_fallback_policies/requeue'
require 'concurrent'

module Aggredator

  class SimplePoolFactory
    def self.call(pool_size, queue_size)
      Aggredator::App::ThreadPool.new(pool_size, queue: queue_size)
    end
  end

  class ConcurrentPoolFactory
    def self.call(pool_size, queue_size)
      Concurrent::FixedThreadPool.new(pool_size, max_queue: queue_size, fallback_policy: :caller_runs)
    end
  end 

  class Dispatcher
    attr_accessor :supress_exception, :message_fallback_policy
    attr_reader :consumers, :publishers, :observer, :middlewares, :logger

    ANSWER_DOMAIN = 'answer'

    QUEUE_STREAM = :queue
    POOL_STREAM = :pool
    SIMPLE_POOL = :simple
    CONCURRENT_POOL = :concurrent

    class Exception < RuntimeError; end
    class StopException < Exception; end
    class RejectException < Exception; end

    def initialize observer, pool_size: 3, logger: Aggredator::App.logger, pool_factory: SimplePoolFactory, stream_strategy: QueueStreamStrategy, message_fallback_policy: MessageFallbackPolicies::Reject.new(logger: Aggredator::App.logger)
      @observer = observer
      @pool_size = pool_size
      logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
      @logger = Aggredator::App::ProxyLogger.new(logger, tags: 'Dispatcher')
      @consumers = []
      @publishers = []
      @middlewares = []
      @pool_factory = pool_factory
      @stream_strategy_class = stream_strategy
      @message_fallback_policy = message_fallback_policy
      @supress_exception = true
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

    # Run all consumers and blocks on message processing
    def run
      @pool = @pool_factory.call(@pool_size, 10)
      @stream_strategy = @stream_strategy_class.new(@pool, logger: logger)

      @stream_strategy.run(consumers) do |msg|
        begin
          logger.tagged(msg.headers[:message_id]) do
            process msg
          end
        rescue => e
          logger.fatal "E[#{@stream_strategy_class}]: #{e}"
          logger.fatal "E[#{@stream_strategy_class}]: #{e.backtrace.join("\n")}"
          raise unless supress_exception
        end
      end
    end

    # stop dispatcher and wait for termination
    # Чтоб остановить диспетчер надо:
    # 1. остановить консьюмеры
    # 2. остановить прием новых сообщений - @stream.close
    # 3. дождаться обработки всего в очереди или таймаут
    # 4. остановить потоки
    # 5. остановить паблишеры
    def close timeout = 5
      consumers.each do |cons|
        begin
          cons.stop
        rescue => e
          logger.error "Consumer #{cons} stop error: #{e}"
          logger.debug e.backtrace
        end
      end

      @stream_strategy.stop(5)

      consumers.each do |cons|
        begin
          cons.close
        rescue => e
          logger.error "Consumer #{cons} close error: #{e}"
          logger.debug e.backtrace
        end
      end

      publishers.each do |pub|
        begin
          pub.close
        rescue => e
          logger.error "Publisher #{pub} close error: #{e}"
          logger.debug e.backtrace
        end
      end
    end

    protected

    def process message
      results = build_processing_stack.call(message).select {|e| e.is_a? Aggredator::Dispatcher::Result}
      logger.debug "There are #{results.count} results to send from #{message.headers[:message_id]}..."
      send_results(message, results).value
    rescue StopException => e
      logger.warn "StopException info: #{e.inspect}"
      logger.warn "StopException on processing message with delivery_info = #{format_di(message&.delivery_info).inspect} headers = #{message.headers.inspect}"
      close()
    rescue RejectException => e
      ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: message, exception: e
      message.consumer.nack(message, error: e)
      # SKIP DEBUG LOGGING
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: message, exception: e
      @message_fallback_policy.call(e, message)
      raise
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
      message_id = incoming.headers[:message_id]

      answer = results.find {|msg| msg.route.domain == ANSWER_DOMAIN}
      Concurrent::Promises.zip_futures(*results.map{|result| publish_result(result)}).then do |_successes|
        incoming.consumer.ack(incoming, answer: answer)
      end.rescue do |*errors|
        error = errors.compact.first
        ActiveSupport::Notifications.instrument 'dispatcher.request.result_rejected', msg: incoming, message: error.inspect
        logger.error "[Message#{message_id}] Publish failed: #{error.inspect}"
        @message_fallback_policy.call(error, incoming)
      rescue StandardError => e
        STDERR.puts e.backtrace
        STDERR.puts "[CRITICAL] #{self.class} [#{Process.pid}] failure exiting: #{e.inspect}"
        ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: incoming, exception: e
        sleep(10)
        exit!(1)
      end
    end

    # @return [Concurrent::Promises::ResolvableFuture]
    def publish_result result
      route = result.route
      logger.debug "Publish result to #{route} ..."
      publisher = publishers.find {|pub| pub.protocols.include?(route.scheme)}
      if publisher.nil?
        raise "Not found publisher for scheme #{route.scheme}"
      end
      # return Concurrent::Promises.resolvable_future
      publisher.publish(result)
    end

    def format_di delivery_info
      delivery_info&.to_h.tap do |di|
        if di && di[:channel].is_a?(::Bunny::Channel)
          di[:delivery_tag] = di[:delivery_tag].to_i
          di[:consumer] = 'amqp'
          di[:channel] = di[:channel].id
          di[:message_consumer] = di[:message_consumer].class.to_s
        end
      end
    end

  end
end
