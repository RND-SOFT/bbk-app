# frozen_string_literal: true

module BBK
  module App
    class Factory

      attr_accessor :klass, :instanceargs, :instancekwargs

      def initialize(klass, *args, **kwargs)
        @klass = klass
        @instanceargs = args
        @instancekwargs = kwargs
      end

      def create
        if RUBY_VERSION < '2.7' && instancekwargs.empty?
          klass.new(*instanceargs)
        else
          klass.new(*instanceargs, **instancekwargs)
        end
      end

      def call(*args, **kwargs)
        create.call(*args, **kwargs)
      end

    end
  end
end

