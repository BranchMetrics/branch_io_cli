module BranchIOCLI
  module Command
    class ValidateCommand < Command
      def run!
        configurations = config.configurations || config.xcodeproj.build_configurations.map(&:name)

        tool_helper.pod_install_if_required

        valid = project_matches_keys?(configurations)

        configurations.each do |configuration|
          message = "Validating #{configuration} configuration"
          say "\n<%= color('#{message}', [BOLD, CYAN]) %>\n\n"

          config_valid = true

          unless config.domains.blank?
            domains_valid = helper.validate_project_domains(config.domains, configuration)

            if domains_valid
              say "Project domains match domains parameter. ✅"
            else
              say "Project domains do not match specified domains."
              helper.errors.each { |error| say "  #{error}" }
            end

            config_valid &&= domains_valid
          end

          entitlements_valid = helper.validate_team_and_bundle_ids_from_aasa_files [], false, configuration
          unless entitlements_valid
            say "Universal Link configuration failed validation for #{configuration} configuration."
            helper.errors.each { |error| say " #{error}" }
          end

          config_valid &&= entitlements_valid

          say "Universal Link configuration passed validation for #{configuration} configuration. ✅" if config_valid

          unless config.universal_links_only
            branch_config_valid = helper.project_valid? configuration
            unless branch_config_valid
              say "Branch configuration failed validation for #{configuration} configuration."
              helper.errors.each { |error| say " #{error}" }
            end

            config_valid &&= branch_config_valid

            say "Branch configuration passed validation for #{configuration} configuration. ✅" if config_valid
          end

          valid &&= config_valid
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
          say "Branch keys from project do not match provided keys."
          say " Expected: #{expected_keys.inspect}"
          say " Actual: #{branch_keys.inspect}"
        end

        keys_valid
      end
    end
  end
end
