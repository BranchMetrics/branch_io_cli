module BranchIOCLI
  module Command
    class EnvCommand < Command
      def run!
        if config.show_all?
          say "\n" unless config.quiet
          say "<%= color('CLI version:', BOLD) %> #{VERSION}"
          say env.ruby_header(include_load_path: true)
        else
          script_path = env.completion_script
          if script_path.nil?
            say "Completion script not available for #{env.shell}"
            return 1
          end
          puts script_path
        end

        0
      end
    end
  end
end
