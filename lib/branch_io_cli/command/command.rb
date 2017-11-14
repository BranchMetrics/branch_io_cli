module BranchIOCLI
  module Command
    class Command
      attr_reader :options # command-specific options from CLI
      attr_reader :config # command-specific configuration object

      def initialize(options)
        @options = options
        matches = /BranchIOCLI::Command::(\w+)Command/.match self.class.name
        root = matches[1]

        @config = Object.const_get("BranchIOCLI")
                        .const_get("Configuration")
                        .const_get("#{root}Configuration").new options
      end

      def run!
        # implemented by subclasses
      end

      def helper
        Helper::BranchHelper
      end

      def patch_helper
        Helper::PatchHelper
      end
    end
  end
end
