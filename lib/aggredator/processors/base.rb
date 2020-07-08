# frozen_string_literal: true

module Aggredator
  module Processors
    class Base
      def rule
        unless self.class.respond_to?(:rule)
          raise NotImplementedError, "Not implemented class method rule in #{self.class.name}"
        end

        self.class.rule
      end

      attr_reader :logger

      def initialize(*_args, logger: $logger, **_kwargs)
        @logger = logger || Logger.new(IO::NULL)
      end

      def call(message, results: [])
        debug 'processing message...'

        process(message, results: results)

        results
      end

      def process(_message, results: [])
        raise NotImplementedError, "process method abstract in Processor class. Results count: #{results.count}"
      end

      def make_error_answer(text, request_message, ctx = {})
        error "#{text}. Request properties: #{request_message.properties.inspect}"
        Aggredator::Api::V1::Error.new(
          {
            correlation_id: request_message.message_id || 'unknown',
            original_user_id: request_message.user_id
          },
          ctx.merge(message: text, request_properties: request_message.properties)
        )
      end

      def debug(msg)
        logger.debug "[#{self.class}]: #{msg}"
      end

      def info(msg)
        logger.info "[#{self.class}]: #{msg}"
      end

      def error(msg)
        logger.error "[#{self.class}]: #{msg}"
      end
    end
  end
end
