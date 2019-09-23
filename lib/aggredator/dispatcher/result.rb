module Aggredator

  class Dispatcher

    class Result

      attr_accessor :route, :message, :properties

      def initialize(route, message, properties = {})
        @route = route.is_a?(String) ? Dispatcher::Route.new(route) : route

        raise 'route must be of type Dispatcher::Route' unless @route.is_a?(Dispatcher::Route)

        @message = message
        @properties = properties.deep_dup
      end

    end
  
  end

end

