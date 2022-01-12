require 'bbk/app/matchers/base'

module BBK
  module App
    module Matchers
      class Headers < Base

        def initialize(rule)
          @rule = rule.with_indifferent_access
        end

        def match(headers, _payload = nil, _delivery_info = nil, *_args)
          match_impl(@rule, headers.with_indifferent_access)
        rescue StandardError
          nil
        end


      end
    end
  end
end

