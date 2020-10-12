require 'aggredator/app/thread_pool'
require 'aggredator/dispatcher/message'
require 'aggredator/dispatcher/result'
require 'aggredator/dispatcher/route'
require 'aggredator/dispatcher/message_stream'
require 'aggredator/dispatcher/pool_proxy_stream'
require 'aggredator/dispatcher/undeliverable_error'
require 'concurrent'

module Aggredator
  class Dispatcher
    attr_reader :consumers, :publishers, :observer, :middlewares, :logger

    ANSWER_DOMAIN = 'answer'

    QUEUE_STREAM = :queue
    POOL_STREAM = :pool
    SIMPLE_POOL = :simple
    CONCURRENT_POOL = :concurrent

    def initialize observer, pool_size: 3, logger: Aggredator::App.logger, stream_type: QUEUE_STREAM, pool_type: SIMPLE_POOL
      @observer = observer
      @pool_size = pool_size
      logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
      @logger = Aggredator::App::ProxyLogger.new(logger, tags: 'Dispatcher')
      @consumers = []
      @publishers = []
      @middlewares = []
      @stream_type = stream_type
      @pool_type = pool_type
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
      if @pool_type == SIMPLE_POOL
        @pool = Aggredator::App::ThreadPool.new(@pool_size, queue: 20)
      elsif @pool_type == CONCURRENT_POOL
        @pool = Concurrent::FixedThreadPool.new(@pool_size, max_queue: 20, fallback_policy: :caller_runs)
      else
        raise "invalia dispetcher pool_type: #{@pool_type.inspect}"
      end

      if @stream_type == QUEUE_STREAM
        run_queue_streaming
      elsif @stream_type == POOL_STREAM
        run_pool_streaming
      else
        raise "invalia dispetcher stream_type: #{@stream_type.inspect}"
      end
    end

    # Store all consumed messages in queue and process it in Thread Pool
    def run_queue_streaming
      @stream = MessageStream.new(size: 20)
      @stop_queue_unblocker = Queue.new

      consumers.each{|cons| cons.run(@stream)}
      for msg in @stream
        logger.debug "Consumed message #{msg.headers}"
        @pool.post(msg) do |m|
          begin
            logger.tagged(m.headers[:message_id]) do
              process m
            end
          rescue => e
            logger.fatal "E1: #{e}"
            logger.fatal "E1: #{e.backtrace.join("\n")}"
          end
        end
      end

      @pool.shutdown rescue nil
      @pool.kill unless @pool.wait_for_termination(@stop_queue_timeout)
    ensure
      @stop_queue_unblocker.push(:ok)
    end

    def stop_queue_streaming timeout
      @stop_queue_timeout = timeout

      @stream.close rescue nil
      @stop_queue_unblocker.pop
    end


    # Process consumed message immidiatle after receivingб without intermediate queue
    def run_pool_streaming
      @stream = PoolProxyStream.new do |msg|
        logger.debug "Consumed message from proxy #{msg.headers}"
        @pool.post(msg) do |m|
          begin
            logger.tagged(m.headers[:message_id]) do
              process m
            end
          rescue => e
            logger.fatal "E2: #{e}"
            logger.fatal "E2: #{e.backtrace.join("\n")}"
          end
        end
      end

      consumers.each{|cons| cons.run(@stream)}
      @pool.wait_for_termination
    end

    def stop_pool_streaming timeout
      @stream.close rescue nil

      @pool.shutdown rescue nil
      @pool.kill unless @pool.wait_for_termination(timeout)
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
          cons.close
        rescue => e
          logger.error "Consumer #{cons} stop error: #{e}"
        end
      end

      if @stream_type == QUEUE_STREAM
        stop_queue_streaming(timeout)
      elsif @stream_type == POOL_STREAM
        stop_pool_streaming(timeout)
      else
        raise "invalia dispetcher stream_type: #{@stream_type.inspect}"
      end

      consumers.each do |cons|
        begin
          cons.close
        rescue => e
          logger.error "Consumer #{cons} close error: #{e}"
        end
      end

      publishers.each do |pub|
        begin
          pub.close
        rescue => e
          logger.error "Publisher #{pub} close error: #{e}"
        end
      end
    end

    protected

    def process message
      results = build_processing_stack.call(message).select {|e| e.is_a? Aggredator::Dispatcher::Result}
      logger.debug "There are #{results.count} results to send from #{message[:message_id]}..."
      send_results(message, results).value
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'dispatcher.exception', msg: message, exception: e
      message.consumer.nack(message, error: e)
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
      message_id = incoming.headers[:message_id]

      answer = results.find {|msg| msg.route.domain == ANSWER_DOMAIN}
      Concurrent::Promises.zip_futures(*results.map{|result| publish_result(result)}).then do |_successes|
        incoming.consumer.ack(incoming, answer: answer)
      end.rescue do |*errors|
        error = errors.compact.first
        ActiveSupport::Notifications.instrument 'dispatcher.request.result_rejected', msg: incoming, message: error.inspect
        logger.error "[Message#{message_id}] Publish failed: #{error.inspect}"
        incoming.consumer.nack(incoming, error: error)
      rescue StandardError => e
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

  end
end
