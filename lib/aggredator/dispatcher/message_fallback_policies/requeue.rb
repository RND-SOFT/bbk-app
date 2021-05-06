module Aggredator
  class Dispatcher
    module MessageFallbackPolicies
      class Requeue < Reject
        protected

        def process(message, exception)
          message.consumer.nack(message, error: exception, requeue: true)
        end
      end
    end
  end
end
