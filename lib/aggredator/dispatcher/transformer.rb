module Aggredator

  class Dispatcher
    
    class Transformer

      def call(msg, *args)
        result = self.transform(msg, *args)

        if result.is_a?(::Aggredator::Dispatcher::Message)
          result
        else
          msg
        end
      end

    end

  end

end
