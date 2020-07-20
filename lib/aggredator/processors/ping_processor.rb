module Aggredator
  
  module Processors

    class PingProcessor < Base

      def self.action
        'ping'
      end

      def self.rule
        [:meta, Aggredator::Api::V1::Ping.meta_match_rule]
      end

      def process(message, results: [])
        results << Aggredator::Dispatcher::Result.new(
          "mq://outer@#{message.reply_to}",
          Aggredator::Api::V1::Pong.new({ correlation_id: message.message_id }, message.body)
        )

        results
      end

    end

  end

end

