module Aggredator

  class Factory

    attr_accessor :klass, :instanceargs

    def initialize(klass, *args)
      @klass = klass
      @instanceargs = args
    end

    def create
      klass.new(*instanceargs)
    end

    def call(*args)
      create.call(*args)
    end

  end

end
