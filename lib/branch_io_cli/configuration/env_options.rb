module BranchIOCLI
  module Configuration
    class EnvOptions
      def self.available_options
        [
          Option.new(
            name: :lib_path,
            description: "Path to the installed gem",
            default_value: false,
            aliases: "-l"
          ),
          Option.new(
            name: :assets_path,
            description: "Path to gem assets",
            default_value: false,
            aliases: "-a"
          ),
          Option.new(
            name: :completion_script,
            description: "Path to the completion script for this shell",
            default_value: false,
            aliases: "-c"
          ),
          Option.new(
            name: :shell,
            description: "Name of the shell in use",
            default_value: false,
            aliases: "-s"
          ),
          Option.new(
            name: :verbose,
            description: "Generate verbose output",
            default_value: false,
            aliases: "-V"
          )
        ]
      end
    end
  end
end
