require 'bbk/utils/proxy_logger'

module BBK
  module App
    module Processors
      class Base

        attr_reader :logger

        def initialize(*untyped, logger: BBK::App.logger, **)
          logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
          @logger = BBK::Utils::ProxyLogger.new(logger, tags: self.class.to_s)
        end

        def rule
          unless self.class.respond_to?(:rule)
            raise NotImplementedError.new("Not implemented class method rule in #{self.class.name}")
          end

          self.class.rule
        end

        def call(message, results: [])
          debug 'processing message...'

          process(message, results: results)

          results
        end

        def process(_message, results: [])
          raise NotImplementedError.new("process method abstract in Processor class. Results count: #{results.count}")
        end


        %i[debug info warn error fatal unknown].each do |severity|
          define_method(severity) do |*args|
            logger.public_send(severity, *args)
          end
        end

      end
    end
  end
end

