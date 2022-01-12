require 'bbk/app/version'
require 'bbk/app/factory'
require 'bbk/app/handler'
require 'bbk/app/matchers'
require 'bbk/app/middlewares'
require 'bbk/app/dispatcher'
require 'bbk/app/processors'
require 'bbk/utils/logger'

module BBK
  module App

    class << self

      attr_accessor :logger

    end

    self.logger = BBK::Utils::Logger.default

  end
end

