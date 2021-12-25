require 'bbk/app/processors/ping'

module BBK
  module App
    module Processors
      class Pong < Base

        def process(*)
          logger.debug 'Process Pong message'
        end

      end
    end
  end
end

