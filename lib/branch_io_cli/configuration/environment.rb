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
        # at the command line (br env -c -s zsh).
        def shell
          config.shell.split("/").last.to_sym
        end

        def completion_script
          path = File.join assets_path, "completions", "completion.#{shell}"
          path if File.readable?(path)
        end
      end
    end
  end
end
