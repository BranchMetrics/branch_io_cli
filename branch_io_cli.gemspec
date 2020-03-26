lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "branch_io_cli/version"

Gem::Specification.new do |spec|
  spec.name          = 'branch_io_cli'
  spec.version       = BranchIOCLI::VERSION
  spec.summary       = 'Branch.io command-line interface for mobile app integration'
  spec.description   = 'Set up mobile app projects (currently iOS only) to use the Branch SDK ' \
                         'without opening Xcode. Validate the Universal Link settings for any project.'
  spec.authors       = ['Branch', 'Jimmy Dee']
  spec.email         = ['integrations@branch.io', 'jgvdthree@gmail.com']

  spec.files         = Dir['bin/*', 'lib/**/*'] + %w{README.md LICENSE}
  spec.test_files    = spec.files.grep(/_spec/)

  spec.require_paths = ['lib']
  spec.bindir        = 'bin'
  spec.executables   = %w{branch_io br}

  spec.homepage      = 'http://github.com/BranchMetrics/branch_io_cli'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency 'CFPropertyList', '~> 2.3'
  spec.add_dependency 'cocoapods-core', '~> 1.3'
  spec.add_dependency 'commander', '~> 4.4'
  spec.add_dependency 'pastel', '~> 0.7'
  spec.add_dependency 'pattern_patch', '>= 0.5.4', '~> 0.5'
  spec.add_dependency 'plist', '~> 3.3'
  spec.add_dependency 'rubyzip', '~> 1.1'
  spec.add_dependency 'tty-platform', '~> 0.1'
  spec.add_dependency 'tty-progressbar', '~> 0.13'
  spec.add_dependency 'tty-spinner', '~> 0.7'
  spec.add_dependency 'xcodeproj', '~> 1.4'

  spec.add_development_dependency 'bundler', '>= 1.15'
  spec.add_development_dependency 'cocoapods', '~> 1.3'
  spec.add_development_dependency 'fastlane', '~> 2.69'
  spec.add_development_dependency 'pry', '~> 0.11'
  spec.add_development_dependency 'rake', '< 13'
  spec.add_development_dependency 'rspec', '~> 3.5'
  spec.add_development_dependency 'rspec-simplecov', '~> 0.2'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.3'
  spec.add_development_dependency 'rubocop', '0.50.0'
  spec.add_development_dependency 'simplecov', '~> 0.15'
end
