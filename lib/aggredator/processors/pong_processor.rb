module Aggredator
  module Processors

    class PongProcessor < Base

      def self.action
        'pong'
      end

      def self.rule
        [:meta, Aggredator::Api::Pong.meta_match_rule]
      end

      def process(*); end

    end

  end

end

