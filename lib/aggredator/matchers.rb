module Aggredator

  class Matchers

    def self.create(type, *args)
      case type
      when :meta
        MetadataMatcher.new(args.first)
      when :payload
        PayloadMatcher.new(args.first)
      when :delivery
        DeliveryInfoMatcher.new(args.first)
      when :full
        FullMatcher.new(*args)
      else
        raise "there is no such matcher: #{type}"
      end
    end

  end

  class BaseMatcher

    attr_reader :rule

    def hash
      (self.class.to_s + self.rule.to_s).hash
    end

    def ==(other)
      return self.class == other.class && self.rule == other.rule
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

      keys_deep(result).count == keys_deep(rule).count ? result : nil
    end

  end

  class MetadataMatcher < BaseMatcher

    def initialize(rule)
      @rule = rule.with_indifferent_access
    end

    def match(metadata, _payload, *_args)
      match_impl(@rule, metadata.with_indifferent_access)
    rescue StandardError => e
      nil
    end

  end

  class PayloadMatcher < BaseMatcher

    def initialize(rule)
      @rule = rule.with_indifferent_access
    end

    def match(_metadata, payload, *_args)
      payload = JSON(payload) if payload&.is_a?(String)
      match_impl(@rule, payload.with_indifferent_access)
    rescue StandardError => e
      nil
    end

  end

  class DeliveryInfoMatcher < BaseMatcher

    def initialize(rule)
      @rule = rule.with_indifferent_access
    end

    def match(_metadata, _payload, delivery_info)
      delivery_info = delivery_info.to_hash unless delivery_info.is_a? Hash
      match_impl(@rule, delivery_info.with_indifferent_access)
    rescue StandardError
      nil
    end

    def match_impl(rule, data)
      result = super
      if !result && (key_rule = rule[:routing_key])
        regexp_rule = Regexp.new("\\A#{key_rule.gsub('.', '\.').gsub('*', '\S+').gsub('#', '.*')}\\Z")
        check = regexp_rule.match?(data[:routing_key])
        result = if check
          {'routing_key' => data[:routing_key]}
        end
      end
      result
    end

  end

  class FullMatcher < BaseMatcher

    def initialize(mrule, prule, drule)
      @mm = Aggredator::MetadataMatcher.new(mrule)
      @pm = Aggredator::PayloadMatcher.new(prule)
      @dm = Aggredator::DeliveryInfoMatcher.new(drule)
      @rule = [mrule, prule, drule]
    end

    def match(metadata, payload, delivery_info)
      return unless (mr = @mm.match(metadata, payload, delivery_info))
      return unless (pr = @pm.match(metadata, payload, delivery_info))
      return unless (dr = @dm.match(metadata, payload, delivery_info))

      [mr, pr, dr]
    rescue StandardError => e
      nil
    end

  end

end

