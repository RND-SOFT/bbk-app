module Aggredator

  class Dispatcher
    class UndeliverableError < StandardError

      def initialize(msg)
        super(msg)
        set_backtrace($ERROR_INFO.backtrace) if $ERROR_INFO
      end
    
    end

  end

end

