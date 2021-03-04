require 'aggredator/api/v1'

module Aggredator

  module Middleware
  
    class Legacy < Aggredator::Middleware::Base
    
      def call(msg)
        if msg.headers[:type] == 'Smev3Request'
          msg.headers[:type] = Aggredator::Api::V1::ActionRequest.type
          msg.headers[:action] = 'default'
        elsif msg.headers[:type] == 'exchange_logs_request'
          msg.headers[:type] = Aggredator::Api::V1::Actions::ExchangeLogRequest.type
          msg.headers[:action] = Aggredator::Api::V1::Actions::ExchangeLogRequest.action
        elsif msg.headers[:type] == 'Smev3Result'
          msg.headers[:type] = Aggredator::Api::V1::Responses::Smev3Result.type
          msg.headers[:action] = Aggredator::Api::V1::Responses::Smev3Result.action
        elsif msg.headers[:type] == 'result'
          msg.headers[:type] = Aggredator::Api::V1::ActionResponse.type
        end
       app.call(msg)
      end

    end

  end

end
