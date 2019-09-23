require 'active_record'

module Aggredator

  module Executor
  
    class ActiveRecordPool < Aggredator::Executor::Base
      
      def call(msg)
        ::ActiveRecord::Base.connection_pool.with_connection do
          yield(msg)
        end
      end

    end

  end

end
