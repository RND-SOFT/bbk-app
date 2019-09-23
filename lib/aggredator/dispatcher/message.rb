module Aggredator

  class Dispatcher

    class Message

      attr_reader :delivery_info, :properties, :payload, :body
  
      def initialize(delivery_info, properties, body)
        unless properties.respond_to? :to_h
          raise Dispatcher::UndeliverableError.new('Properties mus be a Hash')
        end
  
        @delivery_info = delivery_info
        @properties = properties.to_h.with_indifferent_access
        @properties[:headers] ||= {}.with_indifferent_access
        @body = body
        @payload = begin
                     JSON(body)
                   rescue StandardError
                     {}
                   end
  
        validate!
      end
  
      def validate!
        raise Dispatcher::UndeliverableError.new('There is no reply_to in message') if reply_to.blank?
  
        raise 'Body must be a string' if body && !body.is_a?(String)
  
        validate_header_diff!(:user_id)
        validate_header_diff!(:reply_to)
        validate_header_diff!(:message_id)
      end
  
      def user_id
        # Сначала берем user_id из заголовков, а только потом из пропертей. Это нужно для того
        # чтоб была возможность реализовать 'republish to self', поскольку RabbitMq
        # контролирует user_id property исходящего сообщения и его нельзя изменить
        headers[:user_id] || properties[:user_id]
      end
  
      def headers
        properties[:headers]
      end
  
      def message_id
        properties[:message_id] || headers[:message_id]
      end
  
      def id
        self.message_id
      end
  
      def reply_to
        properties[:reply_to] || headers[:reply_to] || user_id
      end
  
      def delivery_tag
        delivery_info&.delivery_tag
      end
  
      def redelivered?
        delivery_info&.redelivered?
      end
  
      def reply_message_id(addon)
        Digest::SHA1.hexdigest("#{addon}#{message_id}")
      end
  
      def to_h
        {
          properties: properties,
          body:       body
        }
      end
  
      private
  
        def validate_header_diff!(field)
          return unless headers[field] && @properties[field] && headers[field].to_s != @properties[field].to_s
  
          raise "Diffrent #{field} in headers and props"
        end
  
    end

  end

end
