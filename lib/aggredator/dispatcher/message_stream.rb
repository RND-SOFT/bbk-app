# frozen_string_literal: true

module Aggredator
  class Dispatcher
    class MessageStream

      CLOSE_VALUE = :close

      def initialize
        @queue = Queue.new
        @closed = false
      end

      def push message
        @queue.push message
      end
      alias_method :<<, :push

      def each
        raise StandardError.new('stream closed') if @closed
        return to_enum unless block_given?

        loop do
          value = @queue.pop
          return if @closed || value == CLOSE_VALUE

          yield value
        end
      end

      def close
        @closed = true
        @queue << CLOSE_VALUE
      end

    end
  end
end
