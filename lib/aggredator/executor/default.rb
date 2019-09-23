module Aggredator

  module Executor
  
    class Default < Aggredator::Executor::Base
    
      def call(msg)
        yield(msg)
      end

    end

  end

end

