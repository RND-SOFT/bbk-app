require 'oj'

module BBK
  module App
    module Spec
      class Dispatcher
        class Message < BBK::App::Dispatcher::Message


          def protocol
            :test
          end

          def message_id
            headers[:message_id]
          end

          def reply_to
            headers[:reply_to] || user_id
          end

          def user_id
            headers[:user_id]
          end

        end
      end
    end
  end
end

