module Aggredator
  class Dispatcher
    module MessageFallbackPolicies
      class Reject < Base
        def call(exception, message, *_args, **_kwargs)
          logger.error "Exception info: #{exception.inspect}"
          logger.debug exception.backtrace
          logger.error "Exception on processing message with delivery_info = #{message&.delivery_info.inspect} headers = #{message.headers.inspect}"
          process(message, exception)
        end

        protected

        def process(message, exception)
          message.consumer.nack(message, error: exception)
        end
      end
    end
  end
end
