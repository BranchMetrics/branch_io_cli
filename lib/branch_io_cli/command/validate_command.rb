module BranchIOCLI
  module Command
    class ValidateCommand < Command
      def run!
        valid = true

        configurations = config.configurations || config.xcodeproj.build_configurations.map(&:name)

        configurations.each do |configuration|
          message = "Validating #{configuration} configuration"
          say "\n<%= color('#{message}', [BOLD, CYAN]) %>\n\n"

          config_valid = true

          unless config.domains.blank?
            domains_valid = helper.validate_project_domains(config.domains, configuration)

            if domains_valid
              say "Project domains match :domains parameter: ✅"
            else
              say "Project domains do not match specified :domains"
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

          valid &&= config_valid
        end

        valid ? 0 : 1
      end
    end
  end
end
