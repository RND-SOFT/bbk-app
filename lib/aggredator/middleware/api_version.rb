require 'aggredator/api/v1'

module Aggredator

  module Middleware
  
    class ApiVersion < Base
    
      API_VERSION_HEADER = 'api'.freeze

      def initialize(default_version=Aggredator::Api::V1::API_VERSION)
        @default_version = default_version
      end

      def build(app)
        @app = app
        self
      end

      def call(msg)
        if msg.headers[API_VERSION_HEADER].blank?
          msg.headers[API_VERSION_HEADER] = @default_version
        end
        @app.call(msg)
      end

    end

  end


end