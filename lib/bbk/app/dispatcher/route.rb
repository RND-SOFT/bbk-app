# frozen_string_literal: true

module BBK
  module App
    class Dispatcher
      class Route

        attr_reader :uri, :scheme, :domain, :routing_key

        # Example: mq://gw@service.smev.request
        def initialize(string)
          @uri = URI(string)
          @scheme = uri.scheme
          @domain = uri.user
          @routing_key = "#{uri.host}#{uri.path}"

          # raise 'domain must present in route' if @domain.blank?
          raise 'routing_key must present in route' if @routing_key.blank?
        end

        def to_s
          @uri.to_s
        end

        def ==(other)
          if other.is_a?(String)
            to_s == other
          else
            super
          end
        end

        def params
          @params ||= Hash[URI.decode_www_form(uri.query.presence || '')] 
        end

      end
    end
  end
end

