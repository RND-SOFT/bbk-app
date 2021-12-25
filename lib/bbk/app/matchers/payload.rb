require 'bbk/app/matchers/base'

module BBK
  module App
    module Matchers
      class Payload < Base

        def initialize(rule)
          @rule = rule.with_indifferent_access
        end

        def match(_headers, payload, _delivery_info = nil, *_args)
          payload = JSON(payload) if payload&.is_a?(String)
          match_impl(@rule, payload.with_indifferent_access)
        rescue StandardError
          nil
        end

      end
    end
  end
end

