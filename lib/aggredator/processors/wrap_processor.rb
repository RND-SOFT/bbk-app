module Aggredator

  module Processors

    class WrapProcessor

      attr_reader :wrapped, :args, :kwargs

      delegate :action, :rule, to: :wrapped

      def initialize(wrapped, *args, **kwargs)
        @wrapped = wrapped
        @args = args
        @kwargs = kwargs
      end

      def call(message, results: [])
        process message, results: results
      end

      def process(message, results: [])
        processor = if wrapped.is_a? Class
          wrapped.new(*@args, **@kwargs)
        else
          wrapped
        end
        temp_results = []
        processor.process(preprocess_message(message), results: temp_results)
        temp_results.each do |res|
          results << postprocess_result(res, message)
        end
      end

      def preprocess_message(message)
        message
      end

      def postprocess_result(result, _message)
        result
      end

    end

  end

end

