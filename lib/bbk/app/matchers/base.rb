module BBK
  module App
    module Matchers
      class Base

        attr_reader :rule

        def hash
          (self.class.to_s + rule.to_s).hash
        end

        def ==(other)
          self.class == other.class && rule == other.rule
        end

        def eql?(other)
          self == other
        end

        def keys_deep(data)
          data.inject([]) do |res, p|
            k, _v = p
            res.push k
            res += keys_deep(data[k]) if data[k].is_a? Hash
            res
          end
        end

        def match_impl(rule, data)
          result = rule.each_with_object({}.with_indifferent_access) do |p, res|
            k, v = p

            if v == :any && data.key?(k.to_sym)
              res[k.to_sym] = data[k.to_sym]
            elsif v.is_a? Hash
              res[k.to_sym] = match_impl(v, data[k.to_sym] || {})
            elsif v == data[k.to_sym]
              res[k.to_sym] = data[k.to_sym]
            end
          end

          result.keys.size == rule.keys.size && keys_deep(result).count >= keys_deep(rule).count ? result : nil
        end


      end
    end
  end
end

