module Aggredator

  module Processors

    class Action < Base

      def self.action
        raise 'action not implemented'
      end

      def action
        self.class.action
      end

    end
  
  end

end

