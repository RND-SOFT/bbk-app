module BBK
  module App
    module Middlewares
      class SelfKiller


        SELF_KILLER_LOG_INTERVAL = 300

        attr_reader :dispatcher, :count, :threshold, :stop_time

        def initialize(dispatcher, delay: 10 * 60, threshold: 10_000, logger: ::Logger.new(STDOUT))
          @dispatcher = dispatcher
          @threshold = threshold
          @count = 0
          @stop_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay
          @stopping = false
          @logger = logger
          @logger.info "[SelfKiller] Initializing: #{@count}/#{@threshold}"
          reset_log_timer
        end

        def build(app)
          @app = app
          self
        end

        def call(msg)
          @count += 1
          if time_exceed?(@log_timer)
            @logger.info "[SelfKiller] Threshold status: #{@count}/#{@threshold}, delayed: #{!time_exceed?}"
            reset_log_timer
          end
          close_dispatcher if stop?

          @app.call(msg)
        end

        protected

          def reset_log_timer
            @log_timer = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SELF_KILLER_LOG_INTERVAL
          end

          def stop?
            !@stopping && threshold_exceed? && time_exceed?
          end

          def threshold_exceed?
            @count > @threshold
          end

          def time_exceed?(time = @stop_time)
            Process.clock_gettime(Process::CLOCK_MONOTONIC) > time
          end

          def close_dispatcher
            @stopping = true
            @logger.warn '[SelfKiller] Threshold exceeded, closing dispatcher...'
            Thread.new { @dispatcher.close } # Don't block current call
          end

      end
    end
  end
end

