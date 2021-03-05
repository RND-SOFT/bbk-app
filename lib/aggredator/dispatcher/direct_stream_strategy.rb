require 'aggredator/dispatcher/pool_proxy_stream'

module Aggredator
  class Dispatcher
    class DirectStreamStrategy
      attr_reader :stream

      def initialize(pool, logger:)
        @pool = pool
        @logger = logger
      end

      def run(consumers, &block)
        @stream = Aggredator::Dispatcher::PoolProxyStream.new do |msg|
          @logger.debug "[#{self.class}] Consumed message #{msg.headers}"
          @pool.post(msg) do |m|
            block.call(m)
          end
        end

        consumers.each { |cons| cons.run(@stream) }
        @pool.wait_for_termination
      end

      def push(*args)
        @stream.push(*args)
      end

      def stop(timeout = 5)
        begin
          @stream.close
        rescue StandardError
          nil
        end

        begin
          @pool.shutdown
        rescue StandardError
          nil
        end
        @pool.kill unless @pool.wait_for_termination(timeout)
      end
    end
  end
end
