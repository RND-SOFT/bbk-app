module Aggredator

  class Handler

    def initialize(&block)
      @handlers = {}
      @default =  if block_given?
        block
      else
        ->(*_args) do
          # delivery_info, properties, body = message
        end
      end
    end

    def wrap(klass, *args)
      Aggredator::Factory.new(klass, *args)
    end

    # регистрация обработчика
    # тип матчера, парметры матчера, Обработчик | Класс обработчика, [аргументы обработчика]
    def register(*args, &block)
      type, rule, callable = nil

      args.push block if block_given?
      if args.first.respond_to?(:rule)
        type, *rule = args.first.rule
      elsif args.first.is_a?(Symbol) || args.first.is_a?(String)
        type = args.shift.to_sym
        raise "rule is not a Hash: #{args.inspect}" unless args.first.is_a?(Hash)

        rule = args.shift
      else
        raise "type and rule or method :rule missing: #{args.inspect}"
      end

      callable = if args.first.is_a?(Class)
        Aggredator::Factory.new(*args)
      elsif args.first.respond_to?(:call)
        args.first
      else
        raise "callable object or class missing: #{args.inspect}"
      end

      @handlers[Aggredator::Matchers.create(type, *[rule].flatten)] = callable
    end

    def default(&block)
      @default = block
    end

    def match(metadata, payload, delivery_info)
      @handlers.each_with_object([nil, @default]) do |p, _res|
        m, h = p
        if (match = m.match(metadata, payload, delivery_info))
          break [match, h]
        end
      end
    end


  end

end