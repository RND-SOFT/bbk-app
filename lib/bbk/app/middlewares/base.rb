module BBK
  module App
    module Middlewares
      class Base

        attr_reader :app

        def initialize(app)
          @app = app
        end

        def call(_msg)
          raise 'Middleware not implemented!'
        end

      end
    end
  end
end

