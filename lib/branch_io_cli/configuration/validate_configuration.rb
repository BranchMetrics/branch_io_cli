module BranchIOCLI
  module Configuration
    class ValidateConfiguration < Configuration
      attr_reader :xcodeproj_path
      attr_reader :xcodeproj
      attr_reader :target
      attr_reader :domains

      def initialize(options)
        super
        @domains = options.domains
        print_identification "validate"
        validate_options
        log
      end

      def validate_options
        validate_xcodeproj_path
        validate_target
      end

      def log
        say <<EOF
<%= color('Configuration:', BOLD) %>

<%= color('Xcode project:', BOLD) %> #{@xcodeproj_path}
<%= color('Target:', BOLD) %> #{@target.name}
<%= color('Domains:', BOLD) %> #{@domains || '(none)'}
EOF
      end
    end
  end
end
