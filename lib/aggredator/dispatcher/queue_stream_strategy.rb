require 'aggredator/dispatcher/message_stream'

module Aggredator
  class Dispatcher
    class QueueStreamStrategy
      def initialize(pool, logger:)
        @pool = pool
        @logger = logger
      end

      def run(consumers, &block)
        @unblocker = Queue.new
        @stream = Aggredator::Dispatcher::MessageStream.new(size: 10)

        consumers.each { |cons| cons.run(@stream) }
        @stream.each do |msg|
          @logger.debug "[#{self.class}] Consumed message #{msg.headers}"
          @pool.post(msg) do |m|
            block.call(m)
          end
        end

        begin
          @pool.shutdown
        rescue StandardError
          nil
        end
        @pool.kill unless @pool.wait_for_termination(@stop_queue_timeout)
      ensure
        @unblocker.push(:ok)
      end

      def push(*args)
        @stream.push(*args)
      end

      def stop(timeout = 5)
        @stop_queue_timeout = timeout

        begin
          @stream.close
        rescue StandardError
          nil
        end
        @unblocker.pop
      end
    end
  end
end
