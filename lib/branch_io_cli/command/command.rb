module BranchIOCLI
  module Command
    class Command
      attr_reader :options
      attr_reader :config # command-specific configuration object

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
