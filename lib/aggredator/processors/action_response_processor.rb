module Aggredator

  module Processors


    class ActionResponseProcessor < ActionProcessor

      def self.rule
        [:meta, Aggredator::Api::V1::ActionResponse.meta_match_rule]
      end

    end

  end

end

