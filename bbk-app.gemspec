lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bbk/app/version'

Gem::Specification.new do |spec|
  spec.name          = 'bbk-app'
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{BBK::App::VERSION}.#{ENV['BUILDVERSION'].to_i}" : BBK::App::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']

  spec.summary       = 'Classes for building services based on BBK stack'
  spec.description   = 'Classes for building services based on BBK stack'

  spec.files         = Dir['bin/*', 'lib/**/*', 'sig/**/*', 'Gemfile*', 'LICENSE.txt', 'README.md']
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 6.0'
  spec.add_runtime_dependency 'oj'
  spec.add_runtime_dependency 'timeouter'

  spec.add_runtime_dependency 'bbk-utils', '> 1.0.1'

  spec.add_development_dependency 'activerecord', '~> 6.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'bunny-mock', '~> 1.7.0'
  spec.add_development_dependency 'database_cleaner', '~> 1.7'
  spec.add_development_dependency 'faker', '~> 2'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'

  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubycritic'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
end

