require 'bbk/app/matchers/headers'
require 'bbk/app/matchers/payload'
require 'bbk/app/matchers/delivery_info'
require 'bbk/app/matchers/full'

module BBK
  module App
    module Matchers

      def self.create(type, *args)
        case type
        when :meta, :headers
          Headers.new(args.first)
        when :payload
          Payload.new(args.first)
        when :delivery, :delivery_info
          DeliveryInfo.new(args.first)
        when :full
          Full.new(*args)
        else
          raise "there is no such matcher: #{type}"
        end
      end

    end
  end
end

