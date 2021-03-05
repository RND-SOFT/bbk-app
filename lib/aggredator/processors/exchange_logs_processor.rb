# frozen_string_literal: true

module Aggredator
  module Processors
    class ExchangeLogsProcessor < Action
      attr_accessor :service_name

      def self.rule
        [:meta, Aggredator::Api::V1::Actions::ExchangeLogRequest.meta_match_rule]
      end

      def self.action
        Aggredator::Api::V1::Actions::ExchangeLogRequest.action
      end

      def initialize(service_name, **kwargs)
        super(**kwargs)
        @service_name = service_name
      end

      def process(message, results: [])
        info "Exchange log message: #{message.properties.inspect}"

        results << Aggredator::Dispatcher::Result.new(
          "mq://inner@service.#{service_name}.request",
          Aggredator::Api::V1::Actions::ExchangeLogRequest.new(
            message.headers.except(:user_id).merge(consumer: message.reply_to || message.user_id), message.payload
          )
        )

        results
      end
    end
  end
end
