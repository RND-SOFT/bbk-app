module Aggredator

  module Processors


    class ActionResponseProcessor < ActionProcessor

      def self.rule
        [:meta, Aggredator::Api::ActionResponse.meta_match_rule]
      end

    end

  end

end

