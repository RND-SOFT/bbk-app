# frozen_string_literal: true

module Aggredator
  class Dispatcher
    class MessageStream
      CLOSE_VALUE = :close
      attr_reader :queue

      def initialize size: 10
        @queue = SizedQueue.new(size)
        @closed = false
      end

      def push(message)
        @queue.push(message) unless @closed
      end
      alias << push

      def each *args, &block
        Enumerator.new do |y|
          loop do
            value = @queue.pop
            break if value == CLOSE_VALUE

            y << value
          end unless @closed
        end.each(*args, &block)
      end

      def close
        @closed = true
        @queue << CLOSE_VALUE
      end

    end
  end
end
