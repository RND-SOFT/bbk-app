# frozen_string_literal: true

module Aggredator
  class Dispatcher
    class MessageStream
      CLOSE_VALUE = :close
      attr_reader :queue, :stream

      def initialize(size: 10)
        @queue = SizedQueue.new(size)
        @closed = false
      end

      def push(message)
        @queue.push(message) unless @closed
      end
      alias << push

      def each
        return to_enum unless block_given?
        return nil if @closed

        loop do
          value = @queue.pop
          break if value == CLOSE_VALUE

          yield(value)
        end
      end

      def close
        @closed = true
        @queue << CLOSE_VALUE
      end
      
    end
  end
end
