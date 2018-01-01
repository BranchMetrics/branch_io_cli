module BranchIOCLI
  module Configuration
    class Environment
      class << self
        def config
          Configuration.current
        end

        def from_homebrew?
          ENV["BRANCH_IO_CLI_INSTALLED_FROM_HOMEBREW"] == "true"
        end

        def lib_path
          File.expand_path File.join("..", "..", ".."), __FILE__
        end

        def assets_path
          File.join lib_path, "assets"
        end

        # Returns the last path component as a symbol, e.g.
        # :bash, :zsh. Uses the SHELL env. var. unless overriden
        # at the command line (br env -cs zsh).
        def shell
          return ENV["SHELL"] unless config.respond_to?(:shell)
          config.shell.split("/").last.to_sym
        end

        def completion_script
          path = File.join assets_path, "completions", "completion.#{shell}"
          path if File.readable?(path)
        end

        def ruby_header(terminal: true, include_load_path: false)
          if terminal
            header = "<%= color('Ruby version:', BOLD) %> #{RUBY_VERSION}\n"
            header += "<%= color('RubyGems version:', BOLD) %> #{Gem::VERSION}\n"
            header += "<%= color('Bundler:', BOLD) %> #{defined?(Bundler) ? Bundler::VERSION : 'no'}\n"
            header += "<%= color('Installed from Homebrew:', BOLD) %> #{from_homebrew? ? 'yes' : 'no'}\n"
            header += "<%= color('GEM_HOME:', BOLD) %> #{obfuscate_user(Gem.dir)}\n"
            header += "<%= color('Lib path:', BOLD) %> #{display_path(lib_path)}\n"
            header += "<%= color('LOAD_PATH:', BOLD) %> #{$LOAD_PATH.map { |p| display_path(p) }}\n" if include_load_path
            header += "<%= color('Shell:', BOLD) %> #{ENV['SHELL']}\n\n"
          else
            header = "Ruby version: #{RUBY_VERSION}\n"
            header += "RubyGems version: #{Gem::VERSION}\n"
            header += "Bundler: #{defined?(Bundler) ? Bundler::VERSION : 'no'}\n"
            header += "Installed from Homebrew: #{from_homebrew? ? 'yes' : 'no'}\n"
            header += "GEM_HOME: #{obfuscate_user(Gem.dir)}\n"
            header += "Lib path: #{display_path(lib_path)}\n"
            header += "LOAD_PATH: #{$LOAD_PATH.map { |p| display_path(p) }}\n" if include_load_path
            header += "Shell: #{ENV['SHELL']}\n\n"
          end
          header
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
end
