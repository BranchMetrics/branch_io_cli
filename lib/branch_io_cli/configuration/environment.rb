require "active_support/core_ext/string"
require "rbconfig"
require_relative "../core_ext/tty_platform"

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

          os += " (#{os_arch})"

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

        # Returns the last path component. Uses the SHELL env. var. unless overriden
        # at the command line (br env -cs zsh).
        def shell
          return ENV["SHELL"].split("/").last unless config.class.available_options.map(&:name).include?(:shell)
          config.shell.split("/").last
        end

        def completion_script
          path = File.join assets_path, "completions", "completion.#{shell}"
          path if File.readable?(path)
        end

        def ruby_header(terminal: true, include_load_path: false)
          header = header_item("Operating system", operating_system, terminal: terminal)
          header += header_item("Ruby version", RUBY_VERSION, terminal: terminal)
          header += header_item("Ruby path", display_path(ruby_path), terminal: terminal)
          header += header_item("RubyGems version", Gem::VERSION, terminal: terminal)
          header += header_item("Bundler", defined?(Bundler) ? Bundler::VERSION : "no", terminal: terminal)
          header += header_item("Installed from Homebrew", from_homebrew? ? "yes" : "no", terminal: terminal)
          header += header_item("GEM_HOME", obfuscate_user(Gem.dir), terminal: terminal)
          header += header_item("Lib path", display_path(lib_path), terminal: terminal)
          header += header_item("LOAD_PATH", $LOAD_PATH.map { |p| display_path(p) }, terminal: terminal) if include_load_path
          header += header_item("Shell", ENV["SHELL"], terminal: terminal)
          header += "\n"
          header
        end

        def header_item(label, value, terminal: true)
          if terminal
            "<%= color('#{label}:', BOLD) %> #{value}\n"
          else
            "label: #{value}\n"
          end
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
