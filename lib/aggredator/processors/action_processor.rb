module Aggredator
  module Processors
    class ActionProcessor < Base
      def self.rule
        [:meta, Aggredator::Api::V1::ActionRequest.meta_match_rule]
      end

      def initialize(*args, supress_exception: true, **kwargs)
        super
        @supress_exception = supress_exception
      end

      # examples:
      # Processor instance MUST respond_to? :call
      #
      # register :test, Processor.new
      # register :test, Processor, 'arg1'...
      # register :test {|msg| ...}
      #
      # If Processor class respond_to? :action
      # register Processor, 'arg1'...
      #
      # If Processor instance respond_to? :action
      # register Processor.new
      def register(*args, &block)
        @actions ||= {}
        action, callable = nil

        args.push block if block_given?

        action = if args.first.respond_to?(:action)
                   args.first.action
                 elsif args.first.is_a?(Symbol) || args.first.is_a?(String)
                   args.shift
                 else
                   raise "action name or method :action missing: #{args.inspect}"
                 end

        callable = if args.first.is_a?(Class)
                     Aggredator::Factory.new(*args)
                   elsif args.first.respond_to?(:call)
                     args.first
                   else
                     raise "callable object or class missing: #{args.inspect}"
                   end

        if @actions.key?(action.to_s)
          warn("Action with same name already registered: #{action}. Args: #{args.inspect}. Backtrace: #{caller.first(15).inspect}")
        end

        @actions[action.to_s] = callable
      end

      def process(message, results: [])
        current_action = (message.headers[:action] || 'default').to_s
        debug "ActionRequest[#{current_action.inspect}] request: #{message.properties.inspect}."
        handler = @actions[current_action]

        if handler.present?
          ActiveSupport::Notifications.instrument 'action_processor.action', action: current_action,
                                                                             headers: message.headers do
            handler.call(message, results: results)
          end
        else
          ActiveSupport::Notifications.instrument 'action_processor.action_missing', action: current_action,
                                                                                     headers: message.headers
          results << Aggredator::Dispatcher::Result.new(
            "mq://outer@#{message.reply_to}",
            make_error_answer("No such action[#{current_action}]", message)
          )
        end

        results
      rescue StandardError => e
        raise unless @supress_exception

        error "Exception: #{e.inspect}"
        error e.backtrace.join("\n")
        ActiveSupport::Notifications.instrument 'action_processor.exception', action: current_action,
                                                                              headers: message.headers, exception: e, processor: handler
        results.clear
        results << Aggredator::Dispatcher::Result.new(
          "mq://outer@#{message.reply_to}",
          make_error_answer("Exception in action[#{current_action}]: #{e.inspect}", message)
        )

        results
      end
    end
  end
end
