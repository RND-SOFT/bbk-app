module BBK
  module App
    module Middlewares
      class FromBlock < Base

        def initialize(&block)
          raise ArgumentError.new('Not passed block') unless block_given?

          @block = block
        end

        def build(app)
          @app = app
          self
        end

        def call(msg)
          @block.call(app, msg)
        end


      end
    end
  end
end

