module BBK
  module App
    class Dispatcher
      class Result

        attr_accessor :route, :message

        def initialize(route, message)
          @route = route.is_a?(String) ? Dispatcher::Route.new(route) : route

          raise 'route must be of type Dispatcher::Route' unless @route.is_a?(Dispatcher::Route)

          @message = message
        end

        def deconstruct
          [route.to_s, message]
        end

        def deconstruct_keys(_keys)
          {route: route.to_s, message: message}
        end

      end
    end
  end
end

