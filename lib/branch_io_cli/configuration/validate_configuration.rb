module BranchIOCLI
  module Configuration
    class ValidateConfiguration < Configuration
      class << self
        def return_value
          "If validation passes, this command returns 0. If validation fails, it returns 1."
        end

        def available_options
          [
            Option.new(
              name: :domains,
              description: "Comma-separated list of domains to validate (Branch domains or non-Branch domains)",
              type: Array,
              example: "example.com,www.example.com",
              aliases: "-D"
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
            )
          ]
        end
      end

      def initialize(options)
        super
        @domains = options.domains
      end

      def validate_options
        validate_xcodeproj_path
        validate_target
      end

      def log
        super
        say <<EOF
<%= color('Xcode project:', BOLD) %> #{xcodeproj_path}
<%= color('Target:', BOLD) %> #{target.name}
<%= color('Domains:', BOLD) %> #{domains || '(none)'}
EOF
      end
    end
  end
end
