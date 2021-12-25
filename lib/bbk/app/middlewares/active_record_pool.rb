require 'active_record'
require 'bbk/app/middlewares/base'

module BBK
  module App
    module Middlewares
      class ActiveRecordPool < Base


        def call(msg)
          ::ActiveRecord::Base.connection_pool.with_connection do
            app.call(msg)
          end
        end


      end
    end
  end
end

