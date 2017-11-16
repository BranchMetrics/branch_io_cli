module BranchIOCLI
  module Command
    class Command
      class << self
        def command_name
          matches = /BranchIOCLI::Command::(\w+)Command/.match name
          matches[1].downcase
        end

        def configuration_class
          root = command_name.capitalize

          Object.const_get("BranchIOCLI")
                .const_get("Configuration")
                .const_get("#{root}Configuration")
        end

        def available_options
          configuration_class.available_options
        end

        def examples
          configuration_class.examples if configuration_class.respond_to?(:examples)
        end

        def return_value
          configuration_class.return_value if configuration_class.respond_to?(:return_value)
        end
      end

      attr_reader :options # command-specific options from CLI
      attr_reader :config # command-specific configuration object

      def initialize(options)
        @options = options
        @config = self.class.configuration_class.new options
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
