module BBK
  module App
    class Handler

      def initialize(&block)
        @handlers = {}
        @default = if block_given?
          block
        else
          lambda do |*_args|
            # delivery_info, properties, body = message
          end
        end
      end

      # регистрация обработчика
      # тип матчера, парметры матчера, Обработчик | Класс обработчика, [аргументы обработчика]
      def register(*args, **kwargs, &block)
        type, rule, callable = nil

        if args.first.respond_to?(:rule)
          type, *rule = args.first.rule
        elsif args.first.is_a?(Symbol) || args.first.is_a?(String)
          type = args.shift.to_sym
          rule = args.shift
          if rule.nil?
            $logger&.warn("Not found processor rule in positional arguments. Use keyword arguments #{kwargs} as rule")
            rule = kwargs
            kwargs = {}
          end
          raise "rule is not a Hash: #{args.inspect}" unless rule.is_a?(Hash)
        else
          raise "type and rule or method :rule missing: #{args.inspect}"
        end
        args.push block if block_given?

        callable = if args.first.is_a?(Class)
          BBK::App::Factory.new(*args, **kwargs)
        elsif args.first.respond_to?(:call)
          args.first
        else
          raise "callable object or class missing: #{args.inspect}"
        end

        matcher = BBK::App::Matchers.create(type, *[rule].flatten)
        @handlers.each do |m, _c|
          $logger&.warn("Handler with same matcher already registered: #{m.inspect}") if m == matcher
        end

        @handlers[BBK::App::Matchers.create(type, *[rule].flatten)] = callable
      end

      def default(&block)
        @default = block
      end

      def match(metadata, payload, delivery_info)
        @handlers.each_with_object([nil, @default]) do |p, _res|
          m, h = p
          if (match = m.match(metadata, payload, delivery_info))
            return [match, h]
          end
        end
      end

    end
  end
end

