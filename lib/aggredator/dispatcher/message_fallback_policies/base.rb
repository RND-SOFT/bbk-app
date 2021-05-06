module Aggredator

  class Dispatcher
  
    module MessageFallbackPolicies
   
      class Base
        attr_reader :logger
        def initialize(logger: ::Logger.new(IO::NULL))
          @logger = logger
        end
        def call(exception, message, *args, **kwargs)
          raise NotImplementedError
        end
      end
    end
  end
end
