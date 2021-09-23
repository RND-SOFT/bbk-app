module Aggredator
  module Middleware
    class SelfKiller
      attr_reader :dispatcher, :count, :threshold, :stop_time

      def initialize(dispatcher, delay: 10 * 60, threshold: 10_000)
        @dispatcher = dispatcher
        @threshold = threshold
        @count = 0
        @stop_time = Time.now + delay
        @stopping = false
        @logger = dispatcher.logger
      end

      def build(app)
        @app = app
        self
      end

      def call(msg)
        close_dispatcher if stop?

        @app.call(msg)
      end

      protected

      def stop?
        !@stopping && threshold_exceed && time_exceed
      end

      def threshold_exceed
        @count += 1
        @count > @threshold
      end

      def time_exceed
        Time.now > @stop_time
      end

      def close_dispatcher
        @stopping = true
        @logger.warn 'Self killer threshold exceeded, closing dispatcher...'
        @dispatcher.close
      end
    end
  end
end
