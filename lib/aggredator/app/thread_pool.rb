require 'timeouter'

module Aggredator
  module App
    class ThreadPool
      attr_reader :jobs, :threads

      def initialize(size, queue: 10)
        @jobs = SizedQueue.new(queue)
        @shutdown = false
        @term = false

        @threads = size.times.map do
          Thread.new(@jobs) do |jobs|
            begin
              Thread.current.report_on_exception = true
              Thread.current.abort_on_exception = true

              unless @shutdown
                until @term
                  job, args = jobs.pop
                  break if  @term || job == :exit

                  job.call(*args)
                end
              end
            rescue StandardError => e
              warn "[CRITICAL]: ThreadPool exception: #{e}"
              warn "[CRITICAL]: #{e.backtrace.join("\n")}"
              exit(1)
            end
          end
        end
      end

      def post(*args, &block)
        @jobs << [block, args] unless @shutdown
      end

      def shutdown
        return if @shutdown

        @shutdown = true
        Thread.new { @threads.size.times { @jobs.push(:exit) } }
      end

      def wait_for_termination(timeout = 0)
        Timeouter.run(timeout) do |t|
          @threads.all? do |thread|
            thread.join(t.left)
          end
        end
      end

      alias wait wait_for_termination

      def kill(timeout = 1)
        return if @term

        @term = true
        shutdown
        if wait_for_termination(timeout)
          true
        else
          @threads.each(&:kill)
          false
        end
      end
    end
  end
end
