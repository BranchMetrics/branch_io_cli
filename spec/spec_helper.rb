$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'
require 'rspec/simplecov'

require 'branch_io_cli'

# SimpleCov.minimum_coverage 95
SimpleCov.start
