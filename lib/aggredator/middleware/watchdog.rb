module Aggredator
  module Middleware
    class Watchdog
      attr_reader :publisher, :route, :reply_to, :delay, :timeout, :watcher_delay, :pinger_thread, :watcher_thread

      def initialize(publisher, route, reply_to, delay: 20, timeout: 60, watcher_delay: 40)
        @publisher = publisher
        @route = route
        @reply_to = reply_to
        @delay = delay
        @timeout = timeout
        @timestamp = Time.now.to_i
        @watcher_delay = watcher_delay
      end

      def build(app)
        @app = app
        self
      end

      def call(msg)
        touch
        @app.call(msg)
      end

      def start
        touch
        start_ping
        start_watch
        self
      end

      def stop
        @pinger_thread&.kill
        @watcher_thread&.kill
      end

      protected

      def start_ping
        @pinger_thread = Thread.new(publisher, delay, route) do |publisher, delay, route|
          Thread.current.name = 'WatchDog::Pinger'
          loop do
            publisher.publish Aggredator::Dispatcher::Result.new(
              route,
              Aggredator::Api::V1::Ping.new(
                {
                  message_id: SecureRandom.hex,
                  reply_to: @reply_to
                }
              )
            )
            sleep delay
          end
        end
      end

      def start_watch
        @watcher_thread = Thread.new(timeout, watcher_delay) do |timeout, watcher_delay|
          Thread.current.name = 'WatchDog::Watcher'
          msg = "[CRITICAL] watchdog: last ping is more than #{timeout} seconds ago"

          sleep watcher_delay while (Time.now.to_i - @timestamp) < timeout
          STDERR.puts msg
          exit!(8)
        end
      end

      def touch
        @timestamp = Time.now.to_i
      end
    end
  end
end
