require 'bbk/app/matchers/base'

module BBK
  module App
    module Matchers
      class DeliveryInfo < Base


        def initialize(rule)
          @rule = rule.with_indifferent_access
        end

        def match(_headers, _payload, delivery_info, *_args)
          delivery_info = delivery_info.to_hash unless delivery_info.is_a? Hash
          match_impl(@rule, delivery_info.with_indifferent_access)
        rescue StandardError
          nil
        end

        def match_impl(rule, data)
          result = super
          if !result && (key_rule = rule[:routing_key])
            regexp_rule = Regexp.new("\\A#{key_rule.gsub('.', '\.').gsub('*', '\S+').gsub('#',
                                                                                          '.*')}\\Z")
            check = regexp_rule.match?(data[:routing_key])
            result = ({ 'routing_key' => data[:routing_key] } if check)
          end
          result
        end

      end
    end
  end
end

