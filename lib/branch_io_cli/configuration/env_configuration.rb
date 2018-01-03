module BranchIOCLI
  module Configuration
    class EnvConfiguration < Configuration
      class << self
        def summary
          "Output information about CLI environment."
        end

        def examples
          {
            "Show CLI environment" => "br env",
            "Get completion script for zsh" => "br env -cs zsh"
          }
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
<%= color('Show completion script:', BOLD) %> #{completion_script}
<%= color('Shell for completion script:', BOLD) %> #{shell}
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
