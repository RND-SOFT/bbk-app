# frozen_string_literal: true

module Aggredator
  class Dispatcher
    class PoolProxyStream
      def initialize(&block)
        @block = block
      end

      def push(message)
        @block&.call(message)
      end
      alias << push

      def close
        @block = nil
      end
    end
  end
end
