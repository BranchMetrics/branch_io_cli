require "active_support/core_ext/string"
require "rbconfig"
require "branch_io_cli/core_ext/tty_platform"

module BranchIOCLI
  module Configuration
    class Environment
      PLATFORM = TTY::Platform.new

      class << self
        def config
          Configuration.current
        end

        def os_version
          PLATFORM.version
        end

        def os_name
          PLATFORM.os.to_s.capitalize
        end

        def os_cpu
          PLATFORM.cpu
        end

        def os_arch
          PLATFORM.architecture
        end

        def operating_system
          if PLATFORM.br_high_sierra?
            os = "macOS High Sierra"
          elsif PLATFORM.br_sierra?
            os = "macOS Sierra"
          else
            os = os_name if os_name
            os += " #{os_version}" if os_version
          end

          if os_cpu
            os += " (#{os_cpu} #{os_arch})"
          else
            os += "(#{os_arch})"
          end

          os
        end

        def ruby_path
          File.join(RbConfig::CONFIG["bindir"],
                    RbConfig::CONFIG["RUBY_INSTALL_NAME"] +
                    RbConfig::CONFIG["EXEEXT"])
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
            header = "<%= color('Operating system:', BOLD) %> #{operating_system}\n"
            header += "<%= color('Ruby version:', BOLD) %> #{RUBY_VERSION}\n"
            header += "<%= color('Ruby path:', BOLD) %> #{obfuscate_user(ruby_path)}\n"
            header += "<%= color('RubyGems version:', BOLD) %> #{Gem::VERSION}\n"
            header += "<%= color('Bundler:', BOLD) %> #{defined?(Bundler) ? Bundler::VERSION : 'no'}\n"
            header += "<%= color('Installed from Homebrew:', BOLD) %> #{from_homebrew? ? 'yes' : 'no'}\n"
            header += "<%= color('GEM_HOME:', BOLD) %> #{obfuscate_user(Gem.dir)}\n"
            header += "<%= color('Lib path:', BOLD) %> #{display_path(lib_path)}\n"
            header += "<%= color('LOAD_PATH:', BOLD) %> #{$LOAD_PATH.map { |p| display_path(p) }}\n" if include_load_path
            header += "<%= color('Shell:', BOLD) %> #{ENV['SHELL']}\n\n"
          else
            header = "Operating system: #{operating_system}\n"
            header += "Ruby version: #{RUBY_VERSION}\n"
            header += "Ruby path: #{obfuscate_user(ruby_path)}\n"
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
