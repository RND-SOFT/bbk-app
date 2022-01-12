require 'bbk/app/matchers/headers'
require 'bbk/app/matchers/payload'
require 'bbk/app/matchers/delivery_info'

module BBK
  module App
    module Matchers
      class Full < Base

        def initialize(*args)
          if args.size == 1
            arg = args[0]
            hrule = arg.fetch(:headers, {})
            prule = arg.fetch(:payload, {})
            drule = arg.fetch(:delivery_info, {})
          else
            hrule, prule, drule = *args
          end

          @hm = Headers.new(hrule)
          @pm = Payload.new(prule)
          @dm = DeliveryInfo.new(drule)
          @rule = [hrule, prule, drule]
        end

        def match(headers, payload, delivery_info, *_args)
          return unless (hr = @hm.match(headers, payload, delivery_info))
          return unless (pr = @pm.match(headers, payload, delivery_info))
          return unless (dr = @dm.match(headers, payload, delivery_info))

          [hr, pr, dr]
        rescue StandardError
          nil
        end


      end
    end
  end
end

