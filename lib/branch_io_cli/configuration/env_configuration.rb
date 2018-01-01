module BranchIOCLI
  module Configuration
    class EnvConfiguration < Configuration
      class << self
        def summary
          "Output information about CLI environment."
        end
      end

      def initialize(options)
        @quiet = !options.verbose
        @lib_path = options.lib_path
        @assets_path = options.assets_path
        @completion_script = options.completion_script
        @shell = options.shell
        super
      end

      def log
        super
        return if quiet

        say <<EOF
<%= color('Show lib path:', BOLD) %> #{lib_path}
<%= color('Show assets path:', BOLD) %> #{assets_path}
<%= color('Show completion script:', BOLD) %> #{completion_script}
<%= color('Show shell:', BOLD) %> #{shell}
EOF
      end

      def all?
        !(
          lib_path ||
          assets_path ||
          completion_script ||
          shell
        )
      end
    end
  end
end
