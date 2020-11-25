require 'active_record'

module Aggredator

  module Middleware
  
    class ActiveRecordPool < Aggredator::Middleware::Base

      def call(msg)
        ::ActiveRecord::Base.connection_pool.with_connection do
          app.call(msg)
        end
      end

    end

  end

end
