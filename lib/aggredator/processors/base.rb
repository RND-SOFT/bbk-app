module Aggredator

  module Processors
  
    class Base
      
      def rule
        unless self.class.respond_to?(:rule)
          raise NotImplementedError.new("Not implemented class method rule in #{self.class.name}")
        end
    
        self.class.rule
      end
    
      def initialize(*_args); end
    
      def call(message, results: [])
        $logger&.debug "#{self}: processing message..."
    
        process(message, results: results)
    
        results
      end
    
      def process(_message, results: [])
        raise NotImplementedError.new "process method abstract in Processor class. Results count: #{results.count}"
      end
    
      def make_error_answer(text, request_message, ctx = {})
        $logger&.error "#{text}. Request properties: #{request_message.properties.inspect}"
        Aggredator::Api::Error.new(
          {
            correlation_id:   request_message.message_id || 'unknown',
            original_user_id: request_message.user_id
          },
          ctx.merge(
            message:            text,
            request_properties: request_message.properties
          )
        )
      end

    end

  end

end
