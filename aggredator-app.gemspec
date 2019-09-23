
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "aggredator/version"

Gem::Specification.new do |spec|
  spec.name          = "aggredator-app"
  spec.version       = Aggredator::App::VERSION
  spec.authors       = ["Samoilenko Yuri"]
  spec.email         = ["kinnalru@gmail.com"]

  spec.summary       = 'Classes for building aggredator services'
  spec.description   = 'Classes for building aggredator services'

  spec.files         = Dir['bin/*', 'lib/**/*', "Gemfile*", "LICENSE.txt", "README.md"] 
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
  spec.add_development_dependency 'rubycritic'
  spec.add_development_dependency 'faker', '~> 1.9.6'
  spec.add_development_dependency 'bunny-mock', '~> 1.7.0'
  spec.add_development_dependency 'activerecord', '~> 6.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'database_cleaner', '~> 1.7.0'
end
