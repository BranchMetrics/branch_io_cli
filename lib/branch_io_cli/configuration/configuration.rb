module BranchIOCLI
  module Configuration
    class Configuration
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def log
        # implemented in subclasses
      end

      def print_identification(command)
        say <<EOF

<%= color("branch_io #{command} v. #{VERSION}", BOLD) %>

EOF
      end

      def helper
        Helper::BranchHelper
      end
    end
  end
end
