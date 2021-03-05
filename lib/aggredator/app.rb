require 'aggredator/client'

require 'aggredator/app/version'
require 'aggredator/app/proxy_logger'

require 'aggredator/middleware'
require 'aggredator/factory'
require 'aggredator/matchers'
require 'aggredator/dispatcher'
require 'aggredator/processors'
require 'aggredator/handler'

module Aggredator
  module App
    class << self
      attr_accessor :logger
    end

    self.logger = ::Logger.new(STDOUT)
  end
end
