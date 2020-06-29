module Aggredator

  class Watchdog

    def initialize(client, queue: client.name, delay: 20, timeout: 60, watcher_delay: 40)
      @client = client
      @queue = queue
      @delay = delay
      @timeout = timeout
      @timestamp = Time.now.to_i
      @watcher_delay = watcher_delay
    end

    def start
      startpinger
      startwatcher
      self
    end

    def startpinger
      Thread.new(@delay, @queue) do |delay, queue|
        Thread.current.name = 'WatchDog::pinger'
        loop do
          @client.direct_publish(
            queue,
            Aggredator::Api::V1::Ping.new(
              {
                message_id: SecureRandom.hex,
                reply_to:   queue
              }, 'watchdog ping'
            )
          )
          sleep delay
        end
      end
    end

    def startwatcher
      Thread.new(@timeout, @watcher_delay) do |timeout, watcher_delay|
        Thread.current.name = 'WatchDog::watcher'
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

