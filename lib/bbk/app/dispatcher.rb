require 'concurrent'
require 'bbk/app/thread_pool'
require 'bbk/app/dispatcher/message_stream'
require 'bbk/app/dispatcher/message'
require 'bbk/app/dispatcher/queue_stream_strategy'
require 'bbk/app/dispatcher/result'
require 'bbk/app/dispatcher/route'
require 'bbk/utils/proxy_logger'

module BBK
  module App

    class SimplePoolFactory

      def self.call(pool_size, queue_size)
        BBK::App::ThreadPool.new(pool_size, queue: queue_size)
      end

    end

    class ConcurrentPoolFactory

      def self.call(pool_size, queue_size)
        Concurrent::FixedThreadPool.new(pool_size, max_queue:       queue_size,
                                                   fallback_policy: :caller_runs)
      end

    end

    class Dispatcher

      attr_accessor :force_quit
      attr_reader :consumers, :publishers, :observer, :middlewares, :logger

      ANSWER_DOMAIN = 'answer'

      def initialize(observer, pool_size: 3, logger: BBK::App.logger, pool_factory: SimplePoolFactory, stream_strategy: QueueStreamStrategy)
        @observer = observer
        @pool_size = pool_size
        logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
        @logger = BBK::Utils::ProxyLogger.new(logger, tags: 'Dispatcher')
        @consumers = []
        @publishers = []
        @middlewares = []
        @pool_factory = pool_factory
        @stream_strategy_class = stream_strategy
        @force_quit = false
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
        ActiveSupport::Notifications.instrument 'dispatcher.run', dispatcher: self

        @stream_strategy.run(consumers) do |msg|
          begin
            logger.tagged(msg.headers[:message_id]) do
              process msg
            end
          rescue StandardError => e
            logger.fatal "E[#{@stream_strategy_class}]: #{e}"
            logger.fatal "E[#{@stream_strategy_class}]: #{e.backtrace.join("\n")}"
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
      def close(_timeout = 5)
        ActiveSupport::Notifications.instrument 'dispatcher.close', dispatcher: self
        consumers.each do |cons|
          begin
            cons.stop
          rescue StandardError => e
            logger.error "Consumer #{cons} stop error: #{e}"
            logger.debug e.backtrace
          end
        end

        @stream_strategy.stop(5)

        consumers.each do |cons|
          begin
            cons.close
          rescue StandardError => e
            logger.error "Consumer #{cons} close error: #{e}"
            logger.debug e.backtrace
          end
        end

        publishers.each do |pub|
          begin
            pub.close
          rescue StandardError => e
            logger.error "Publisher #{pub} close error: #{e}"
            logger.debug e.backtrace
          end
        end
      end

      protected

        def process(message)
          results = build_processing_stack.call(message).select do |e|
            e.is_a? BBK::App::Dispatcher::Result
          end
          logger.debug "There are #{results.count} results to send from #{message.headers[:message_id]}..."
          send_results(message, results).value
        rescue StandardError => e
          logger.error "Failed processing message: #{e.inspect}"
          ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: message, exception: e
          message.nack(error: e)
          close if force_quit
        end

        def process_message(message)
          matched, processor = find_processor(message)
          results = []
          begin
            is_unknown = @observer.instance_variable_get('@default') == processor
            ActiveSupport::Notifications.instrument 'dispatcher.request.process', msg: message, match: matched, unknown: is_unknown do
              processor.call(message, results: results)
            end
          rescue StandardError => e
            logger.error "Failed processing message in processor: #{e.inspect}"
            if processor.respond_to?(:on_error)
              results = processor.on_error(message, e)
            else
              raise
            end
          end
          [results].flatten
        rescue StandardError => e
          ActiveSupport::Notifications.instrument 'dispatcher.request.exception', msg: message, match: matched, processor: processor, exception: e
          raise
        end

        def find_processor(msg)
          matched, callback = @observer.match(msg.headers, msg.payload, msg.delivery_info)
          [matched, callback.is_a?(BBK::App::Factory) ? callback.create : callback]
        end

        def build_processing_stack
          stack = proc{|msg| process_message(msg) }
          middlewares.reduce(stack) do |stack, middleware|
            if middleware.respond_to?(:build)
              middleware.build(stack)
            else
              middleware.new(stack)
            end
          end
        end

        def send_results(incoming, results)
          message_id = incoming.headers[:message_id]

          answer = results.find {|msg| msg.route.domain == ANSWER_DOMAIN }
          Concurrent::Promises.zip_futures(*results.map do |result|
                                             publish_result(result)
                                           end).then do |_successes|
            incoming.ack(answer: answer)
          end.rescue do |*errors|
            error = errors.compact.first
            ActiveSupport::Notifications.instrument 'dispatcher.request.result_rejected',
                                                    msg: incoming, message: error.inspect
            logger.error "[Message#{message_id}] Publish failed: #{error.inspect}"
            incoming.nack(error: error)
            close if force_quit
          rescue StandardError => e
            warn e.backtrace
            warn "[CRITICAL] #{self.class} [#{Process.pid}] failure exiting: #{e.inspect}"
            ActiveSupport::Notifications.instrument 'dispatcher.exception', msg:       incoming,
                                                                            exception: e
            sleep(10)
            exit!(1)
          end
        end

        # @return [Concurrent::Promises::ResolvableFuture]
        def publish_result(result)
          route = result.route
          logger.debug "Publish result to #{route} ..."
          publisher = publishers.find {|pub| pub.protocols.include?(route.scheme) }
          raise "Not found publisher for scheme #{route.scheme}" if publisher.nil?

          # return Concurrent::Promises.resolvable_future
          publisher.publish(result)
        end

    end

  end
end

