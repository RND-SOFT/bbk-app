module Aggredator
  class Dispatcher
    module MessageFallbackPolicies
      class Requeue < Reject
        protected

        def process(message, exception)
          logger.info("Requeue message with headers #{message.headers}")
          message.consumer.nack(message, error: exception, requeue: true)
        end
      end
    end
  end
end
