module Aggredator

  module Processors

    class SmevLogRequest < Action

      attr_accessor :model_class, :smev_service_name, :service_name

      def self.rule
        [:meta, Aggredator::Api::Actions::ExchangeLogRequest.meta_match_rule]
      end

      def self.action
        Aggredator::Api::Actions::ExchangeLogRequest.action
      end

      def initialize(model_class, smev_service_name, service_name)
        raise TypeError.new("#{model_class} is not ActiveRecord::Base") unless model_class < ActiveRecord::Base
        raise ArgumentError.new("#{model_class} hasn't column ticket_id") unless model_class.column_names.include? 'ticket_id'
        super
        @model_class = model_class
        @smev_service_name = smev_service_name
        @service_name = service_name
      end

      def process(message, results: [])
        $logger&.info "Exchange log message: #{message.properties.inspect}"

        if (_ticket = model_class.find_by_ticket_id(message.headers[:ticket]))
          results << Aggredator::Dispatcher::Result.new(
            "mq://inner@service.#{smev_service_name}.request",
            Aggredator::Api::Actions::ExchangeLogRequest.new(message.headers.except(:user_id), message.payload)
          )
        else
          error_msg = make_error_answer "Couldn't find request with ticket id: #{message.headers[:ticket].inspect}", message.properties, message.payload
          results << Aggredator::Dispatcher::Result.new(
            "mq://outer@#{message.reply_to}",
            error_msg
          )
        end

        results
      end

      def make_error_answer(message, properties, meta)
        $logger&.error "Build error message: #{message}. Properties: #{properties.inspect}"
        Aggredator::Api::Responses::ExchangeLogResponse.new(
          {
            correlation_id: properties[:message_id] || properties.dig(:headers, :message_id),
            ticket:         properties.dig(:headers, :ticket),
            service:        service_name
          },
          {
            success: false,
            message: message,
            meta:    meta
          }
        )
      end

    end
    
  end

end


