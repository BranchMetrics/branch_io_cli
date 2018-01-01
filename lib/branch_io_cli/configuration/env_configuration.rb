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
        @ruby_version = options.ruby_version
        @rubygems_version = options.rubygems_version
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
<%= color('Completion script:', BOLD) %> #{completion_script}
<%= color('Shell:', BOLD) %> #{shell}
EOF
      end

      def show_all?
        !show_completion_script?
      end

      def show_completion_script?
        completion_script
      end
    end
  end
end
