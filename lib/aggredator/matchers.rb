module Aggredator
  class Matchers
    def self.create(type, *args)
      case type
      when :meta
        HeadersMatcher.new(args.first)
      when :headers
        HeadersMatcher.new(args.first)
      when :payload
        PayloadMatcher.new(args.first)
      when :delivery
        DeliveryInfoMatcher.new(args.first)
      when :delivery_info
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

      keys_deep(result).count == keys_deep(rule).count ? result : nil
    end
  end

  class HeadersMatcher < BaseMatcher
    def initialize(rule)
      @rule = rule.with_indifferent_access
    end

    def match(headers, _payload = nil, _delivery_info = nil, *_args)
      match_impl(@rule, headers.with_indifferent_access)
    rescue StandardError
      nil
    end
  end

  class PayloadMatcher < BaseMatcher
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

  class DeliveryInfoMatcher < BaseMatcher
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
        regexp_rule = Regexp.new("\\A#{key_rule.gsub('.', '\.').gsub('*', '\S+').gsub('#', '.*')}\\Z")
        check = regexp_rule.match?(data[:routing_key])
        result = ({ 'routing_key' => data[:routing_key] } if check)
      end
      result
    end
  end

  class FullMatcher < BaseMatcher
    def initialize(*args)
      if args.size == 1
        arg = args[0]
        hrule = arg[:headers]
        prule = arg[:payload]
        drule = arg[:delivery_info]
      else
        hrule, prule, drule = *args
      end

      @hm = Aggredator::HeadersMatcher.new(hrule)
      @pm = Aggredator::PayloadMatcher.new(prule)
      @dm = Aggredator::DeliveryInfoMatcher.new(drule)
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
