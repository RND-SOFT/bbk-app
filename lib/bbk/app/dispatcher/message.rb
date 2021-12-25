module BBK
  module App
    class Dispatcher
      class Message

        attr_reader :consumer, :delivery_info, :headers, :payload, :body

        def initialize(consumer, delivery_info, headers, body, *_args, **_kwargs)
          @consumer = consumer
          @delivery_info = delivery_info
          @headers = headers.to_h.with_indifferent_access
          @body = body
          @payload = begin
            JSON(body).with_indifferent_access
          rescue StandardError
            {}.with_indifferent_access
          end
        end

        def ack(*args, answer: nil, **kwargs)
          consumer.ack(self, *args, answer: answer, **kwargs)
        end

        def nack(*args, error: nil, **kwargs)
          consumer.nack(self, *args, error: error, **kwargs)
        end

        def message_id
          raise NotImplementedError
        end

        def reply_message_id(addon)
          Digest::SHA1.hexdigest("#{addon}#{message_id}")
        end

        def to_h
          {
            headers: headers,
            body:    body
          }
        end

      end
    end
  end
end

