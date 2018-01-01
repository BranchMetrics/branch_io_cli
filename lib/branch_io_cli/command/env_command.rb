module BranchIOCLI
  module Command
    class EnvCommand < Command
      def run!
        if config.show_all?
          say "\n" unless config.quiet
          say "<%= color('CLI version:', BOLD) %> #{VERSION}"
          say "<%= color('Ruby version:', BOLD) %> #{RUBY_VERSION}"
          say "<%= color('RubyGems version:', BOLD) %> #{Gem::VERSION}"
          say "<%= color('Bundler:', BOLD) %> #{defined?(Bundler) ? Bundler::VERSION : 'no'}"
          say "<%= color('Installed from Homebrew:', BOLD) %> #{env.from_homebrew? ? 'yes' : 'no'}"
          say "<%= color('GEM_HOME:', BOLD) %> #{obfuscate_user(Gem.dir)}"
          say "<%= color('Lib path:', BOLD) %> #{display_path(env.lib_path)}"
          say "<%= color('LOAD_PATH:', BOLD) %> #{$LOAD_PATH.map { |p| display_path(p) }}"
          say "<%= color('Shell:', BOLD) %> #{ENV['SHELL']}"
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

      def obfuscate_user(path)
        path.gsub(ENV['HOME'], '~').gsub(ENV['USER'], '$USER')
      end

      def display_path(path)
        path = path.gsub(Gem.dir, '$GEM_HOME')
        path = obfuscate_user(path)
        path
      end
    end
  end
end
