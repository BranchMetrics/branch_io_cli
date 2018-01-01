module BranchIOCLI
  module Command
    class EnvCommand < Command
      def run!
        if config.all?
          say lib_path
          say assets_path
          say completion_script
          say shell
        end

        if config.lib_path
          say lib_path
        end

        if config.assets_path
          say assets_path
        end

        if config.completion_script
          script_path = completion_script
          say "Completion script not available for #{shell}" and return false if script_path.nil?
          say script_path
        end

        if config.shell
          say shell
        end

        true
      end

      def lib_path
        File.expand_path File.join("..", "..", ".."), __FILE__
      end

      def assets_path
        File.join lib_path, "assets"
      end

      def shell
        ENV["SHELL"].split("/").last.to_sym
      end

      def completion_script
        case shell
        when :bash, :zsh
          path = File.join assets_path, "completions", "completion.#{shell}"
          path if File.readable?(path)
        end
      end
    end
  end
end
