module Aggredator

  module Executor
    class Base

      attr_accessor :dispatcher

      def initialize(*_args); end

      def call(_msg)
        raise 'Executor not implemented!'
      end

    end

  end

end

