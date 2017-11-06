module BranchIOCLI
  module Configuration
    class ValidateConfiguration < Configuration
      attr_reader :domains

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
