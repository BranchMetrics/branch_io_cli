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

        def examples
          {
            "Ensure project has at least one correctly configured Branch key and domain" => "br validate",
            "Ensure project is correctly configured for certain Branch keys" => "br validate -L key_live_xxxx -T key_test_yyyy",
            "Ensure project is correctly configured to use specific domains" => "br validate -D myapp.app.link,myapp-alternate.app.link",
            "Validate only Universal Link configuration" => "br validate --universal-links-only"
          }
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
<%= color('Xcode project:', BOLD) %> #{env.display_path(xcodeproj_path)}
<%= color('Target:', BOLD) %> #{target.name}
<%= color('Target type:', BOLD) %> #{target.product_type}
<%= color('Live key:', BOLD) %> #{keys[:live] || '(none)'}
<%= color('Test key:', BOLD) %> #{keys[:test] || '(none)'}
<%= color('Domains:', BOLD) %> #{domains || '(none)'}
<%= color('Configurations:', BOLD) %> #{(configurations || xcodeproj.build_configurations.map(&:name)).join(',')}
EOF
      end
    end
  end
end
