module Aggredator
  module Processors
    class PongProcessor < Base
      def self.action
        'pong'
      end

      def self.rule
        [:meta, Aggredator::Api::V1::Pong.meta_match_rule[:headers]]
      end

      def process(*); end
    end
  end
end
