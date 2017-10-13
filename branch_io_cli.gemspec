lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "branch_io_cli/version"

Gem::Specification.new do |spec|
  spec.name        = 'branch_io_cli'
  spec.version     = BranchIOCLI::VERSION
  spec.summary     = 'Branch.io command-line interface for mobile app integration'
  spec.description = 'More to come'
  spec.authors     = ['Branch', 'Jimmy Dee']
  spec.email       = ['integrations@branch.io', 'jgvdthree@gmail.com']
  spec.files       = Dir['bin/*', 'lib/**/*.rb']
  spec.homepage    = 'http://github.com/BranchMetrics/branch_io_cli'
  spec.license     = 'MIT'
  spec.bindir      = 'bin'
  spec.executables = %w{branch_io}

  spec.add_dependency 'pattern_patch'
  spec.add_dependency 'plist'
  spec.add_dependency 'xcodeproj'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec-simplecov'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
end
