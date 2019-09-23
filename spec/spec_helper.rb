require "bundler/setup"
require 'simplecov'
require 'simplecov-console'
require 'faker'
require 'securerandom'
require 'aggredator/api'
require 'aggredator/client'
require 'active_record'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Console
])


SimpleCov.start do
  add_filter do |source_file|
    source_file.filename.start_with? File.join(Dir.pwd, 'spec')
  end
end

require "aggredator/app"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

Faker::Config.locale = 'ru'

Dir["./spec/support/**/*.rb"].sort.each {|f| require f}