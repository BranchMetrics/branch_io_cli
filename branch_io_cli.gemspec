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
  spec.executables   = %w{branch_io}

  spec.homepage      = 'http://github.com/BranchMetrics/branch_io_cli'
  spec.license       = 'MIT'

  spec.add_dependency 'CFPropertyList'
  spec.add_dependency 'cocoapods-core'
  spec.add_dependency 'commander'
  spec.add_dependency 'pattern_patch', '>= 0.3.0'
  spec.add_dependency 'plist'
  spec.add_dependency 'rubyzip'
  spec.add_dependency 'xcodeproj'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'cocoapods' # For ease of testing with repo examples
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rspec-simplecov'
  spec.add_development_dependency 'rubocop', '~> 0.50.0'
  spec.add_development_dependency 'simplecov'
end
