module BranchIOCLI
  module Configuration
    class ValidateConfiguration < Configuration
      class << self
        def summary
          "Validates all Universal Link domains configured in a project"
        end

        def return_value
          "If validation passes, this command returns 0. If validation fails, it returns 1."
        end
      end

      def initialize(options)
        super
        @domains = options.domains
      end

      def validate_options
        validate_xcodeproj_path
        validate_target
        validate_keys optional: true
      end

      def log
        super
        say <<EOF
<%= color('Xcode project:', BOLD) %> #{xcodeproj_path}
<%= color('Target:', BOLD) %> #{target.name}
<%= color('Live key:', BOLD) %> #{keys[:live] || '(none)'}
<%= color('Test key:', BOLD) %> #{keys[:test] || '(none)'}
<%= color('Domains:', BOLD) %> #{domains || '(none)'}
<%= color('Configurations:', BOLD) %> #{(configurations || xcodeproj.build_configurations.map(&:name)).join(',')}
EOF
      end
    end
  end
end
