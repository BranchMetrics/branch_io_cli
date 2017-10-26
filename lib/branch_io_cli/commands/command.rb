require "pathname"
require "xcodeproj"

module BranchIOCLI
  module Commands
    class Command
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def run!
        # implemented by subclasses
      end

      def helper
        Helper::BranchHelper
      end

      def config_helper
        Helper::ConfigurationHelper
      end
    end
  end
end
