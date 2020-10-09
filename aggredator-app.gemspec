
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "aggredator/app/version"

Gem::Specification.new do |spec|
  spec.name          = "aggredator-app"
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{Aggredator::App::VERSION}.#{ENV['BUILDVERSION'].to_i}" : Aggredator::App::VERSION
  spec.authors       = ["Samoilenko Yuri"]
  spec.email         = ["kinnalru@gmail.com"]

  spec.summary       = 'Classes for building aggredator services'
  spec.description   = 'Classes for building aggredator services'

  spec.files         = Dir['bin/*', 'lib/**/*', "Gemfile*", "LICENSE.txt", "README.md"] 
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'
  
  spec.add_runtime_dependency 'aggredator-api', '~> 2.0'
  spec.add_runtime_dependency 'aggredator-client', '~> 2.0'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'faker', '~> 2'
  spec.add_development_dependency 'bunny-mock', '~> 1.7.0'
  spec.add_development_dependency 'activerecord', '~> 6.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'database_cleaner', '~> 1.7'

  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
  spec.add_development_dependency 'rubycritic'

end
