require 'active_support'

require 'aggredator/api/v1_compat'
require 'aggredator/processors/base'
require 'aggredator/processors/action_processor'
require 'aggredator/processors/action_response_processor'
require 'aggredator/processors/action'
require 'aggredator/processors/ping_processor'
require 'aggredator/processors/pong_processor'
require 'aggredator/processors/smev_log_processor'
require 'aggredator/processors/wrap_processor'

module Aggredator

  Processor = Aggredator::Processors::Base

  module Processors
  end

end