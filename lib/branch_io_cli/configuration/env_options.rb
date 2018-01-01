module BranchIOCLI
  module Configuration
    class EnvOptions
      def self.available_options
        [
          Option.new(
            name: :completion_script,
            description: "Get the path to the completion script for this shell",
            default_value: false,
            aliases: "-c"
          ),
          Option.new(
            name: :shell,
            description: "Specify shell for completion script",
            type: String,
            default_value: ENV["SHELL"],
            example: "zsh",
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
