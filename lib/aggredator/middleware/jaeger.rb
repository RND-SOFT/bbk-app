require 'opentracing'

module Aggredator

  module Middleware
  
    class Jaeger

      CONTEXT_JAEGER_SPAN_KEY = 'jaeger-span'.freeze

      attr_reader :service_name, :tracer, :default_tags

      def initialize(service_name, tracer, tags: {})
        @service_name = service_name
        @tracer = tracer
        @default_tags = tags.dup.freeze
      end

      def build(app)
        @app = app
        self
      end

      def call(msg)
        span = build_span(msg)
        msg.context[CONTEXT_JAEGER_SPAN_KEY] = span
        results = @app.call(msg)
        span.finish
        results.each {|res| tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, res.message.headers) }
        results
      end

      private

      def build_span(msg)
        msg_type = msg.headers[:type]
        span_name = if msg_type == 'ActionRequest'
          "#{msg_type}:#{msg.headers[:action]}"
        else
          msg_type
        end
        parent_ctx = tracer.extract(OpenTracing::FORMAT_TEXT_MAP, msg.headers)
        tags = {
          type:     msg_type,
          service:  @service_name,
          api:      msg.headers[:api],
          ticket:   msg.headers[:ticket],
          incoming: msg.headers[:incoming]
        }.compact
        tracer.start_span(span_name, child_of: parent_ctx, tags: default_tags.merge(tags))
      end

    end

  end

end