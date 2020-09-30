require 'active_record'

module Aggredator

  module Middleware
  
    class ActiveRecordPool < Aggredator::Middleware::Base

      def call(msg)
        ::ActiveRecord::Base.connection_pool.with_connection do
          app(msg)
        end
      end

    end

  end

end
