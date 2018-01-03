module BranchIOCLI
  module Command
    class ValidateCommand < Command
      def run!
        say "\n"

        configurations = config.configurations || config.xcodeproj.build_configurations.map(&:name)

        return false unless tool_helper.pod_install_if_required

        valid = project_matches_keys?(configurations)
        schemes_valid = uri_schemes_valid?(configurations)
        valid &&= schemes_valid

        configurations.each do |configuration|
          message = "Validating #{configuration} configuration"
          say "\n<%= color('#{message}', [BOLD, CYAN]) %>\n\n"

          config_valid = true

          unless config.domains.blank?
            domains_valid = helper.validate_project_domains(config.domains, configuration)

            if domains_valid
              say "Project domains match domains parameter. ✅"
            else
              say "Project domains do not match specified domains. ❌"
              helper.errors.each { |error| say "  #{error}" }
            end

            config_valid &&= domains_valid
          end

          if config.target.symbol_type == :application
            entitlements_valid = helper.validate_team_and_bundle_ids_from_aasa_files [], false, configuration
            unless entitlements_valid
              say "Universal Link configuration failed validation for #{configuration} configuration. ❌"
              helper.errors.each { |error| say " #{error}" }
            end

            config_valid &&= entitlements_valid

            say "Universal Link configuration passed validation for #{configuration} configuration. ✅" if config_valid
          end

          unless config.universal_links_only
            branch_config_valid = helper.project_valid? configuration
            unless branch_config_valid
              say "Branch configuration failed validation for #{configuration} configuration. ❌"
              helper.errors.each { |error| say " #{error}" }
            end

            config_valid &&= branch_config_valid

            say "Branch configuration passed validation for #{configuration} configuration. ✅" if config_valid
          end

          valid &&= config_valid
        end

        unless valid
          say "\nValidation failed. See errors above marked with ❌."
          say "Please verify your app configuration at https://dashboard.branch.io."
          say "If your Dashboard configuration is correct, br setup will fix most errors."
        end

        valid ? 0 : 1
      end

      def project_matches_keys?(configurations)
        expected_keys = [config.live_key, config.test_key].compact
        return true if expected_keys.empty?

        # Validate the keys in the project against those passed in by the user.
        branch_keys = helper.branch_keys_from_project(configurations).sort

        keys_valid = expected_keys == branch_keys

        say "\n"
        if keys_valid
          say "Branch keys from project match provided keys. ✅"
        else
          say "Branch keys from project do not match provided keys. ❌"
          say " Expected: #{expected_keys.inspect}"
          say " Actual: #{branch_keys.inspect}"
        end

        keys_valid
      end

      def uri_schemes_valid?(configurations)
        uri_schemes = helper.branch_apps_from_project(configurations).map(&:ios_uri_scheme).compact.uniq
        expected = uri_schemes.map { |s| BranchIOCLI::Configuration::Configuration.uri_scheme_without_suffix(s) }.sort
        return true if expected.empty?

        actual = helper.uri_schemes_from_project(configurations).sort
        valid = (expected - actual).empty?
        if valid
          say "URI schemes from project match schemes from Dashboard. ✅"
        else
          say "URI schemes from project do not match schemes from Dashboard. ❌"
          say " Expected: #{expected.inspect}"
          say " Actual: #{actual.inspect}"
        end

        valid
      end
    end
  end
end
