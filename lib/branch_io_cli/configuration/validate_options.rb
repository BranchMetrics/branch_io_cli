module BranchIOCLI
  module Configuration
    class ValidateOptions
      class << self
        def available_options
          [
            Option.new(
              name: :domains,
              description: "Comma-separated list of domains to validate (Branch domains or non-Branch domains)",
              type: Array,
              example: "example.com,www.example.com",
              aliases: "-D",
              default_value: []
            ),
            Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to update",
              type: String,
              example: "MyProject.xcodeproj"
            ),
            Option.new(
              name: :target,
              description: "Name of a target to validate in the Xcode project",
              type: String,
              example: "MyAppTarget"
            ),
            Option.new(
              name: :configurations,
              description: "Comma-separated list of configurations to validate (default: all)",
              type: Array,
              example: "Debug,Release"
            )
          ]
        end
      end
    end
  end
end
