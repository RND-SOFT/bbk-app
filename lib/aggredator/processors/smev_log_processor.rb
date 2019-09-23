module Aggredator

  module Processors

    class SmevLogRequest < Action

      attr_accessor :model_class, :client, :smev_service_name

      def self.rule
        [:meta, Aggredator::Api::ExchangeLogRequest.meta_match_rule]
      end

      def self.action
        Aggredator::Api::ExchangeLogRequest.type
      end

      def initialize(model_class, client, smev_service_name)
        raise TypeError.new("#{model_class} is not ActiveRecord::Base") unless model_class < ActiveRecord::Base
        raise ArgumentError.new("#{model_class} hasn't column ticket_id") unless model_class.column_names.include? 'ticket_id'
        raise TypeError.new('Client is not AggredatorClient::Client') unless client.is_a? Aggredator::Client

        super
        @model_class = model_class
        @client = client
        @smev_service_name = smev_service_name
      end

      def process(message, results: [])
        $logger&.info "Exchange log message: #{message.properties.inspect}"

        if (_ticket = model_class.find_by_ticket_id(message.headers[:ticket]))
          results << Aggredator::Dispatcher::Result.new(
            "mq://inner@service.#{smev_service_name}.request",
            Aggredator::Api::ExchangeLogRequest.new(message.headers.except(:user_id), message.payload)
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
        Aggredator::Api::ExchangeLogResponse.new(
          {
            correlation_id: properties[:message_id],
            ticket:         properties.dig(:headers, :ticket)
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


