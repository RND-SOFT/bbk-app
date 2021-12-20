# frozen_string_literal: true

module Aggredator
  class Factory
    attr_accessor :klass, :instanceargs, :instancekwargs

    def initialize(klass, *args, **kwargs)
      @klass = klass
      @instanceargs = args
      @instancekwargs = kwargs
    end

    def create
      klass.new(*instanceargs, **instancekwargs)
    end

    def call(*args, **kwargs)
      create.call(*args, **kwargs)
    end
  end
end
