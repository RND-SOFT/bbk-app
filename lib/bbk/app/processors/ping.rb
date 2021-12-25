require 'bbk/app/processors/base'

module BBK
  module App
    module Processors
      class Ping < Base

        def initialize(pong_message_factory, pong_route, *args, **kwargs)
          super
          @pong_message_factory = pong_message_factory
          @pong_route = pong_route
        end

        def process(message, results: [])
          results << BBK::App::Dispatcher::Result.new(
            @pong_route,
            @pong_message_factory.build(message)
          )
          results
        end

      end
    end
  end
end

