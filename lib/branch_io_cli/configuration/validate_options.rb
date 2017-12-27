module BranchIOCLI
  module Configuration
    class ValidateOptions
      class << self
        def available_options
          [
            Option.new(
              name: :live_key,
              description: "Branch live key",
              example: "key_live_xxxx",
              type: String,
              aliases: "-L"
            ),
            Option.new(
              name: :test_key,
              description: "Branch test key",
              example: "key_test_yyyy",
              type: String,
              aliases: "-T"
            ),
            Option.new(
              name: :domains,
              description: "Comma-separated list of domains expected to be configured in the project (Branch domains or non-Branch domains)",
              type: Array,
              example: "example.com,www.example.com",
              aliases: "-D",
              default_value: []
            ),
            Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to validate",
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
            ),
            Option.new(
              name: :universal_links_only,
              description: "Validate only the Universal Link configuration",
              default_value: false
            )
          ] + Option.global_options
        end
      end
    end
  end
end
