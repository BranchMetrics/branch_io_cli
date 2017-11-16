module BranchIOCLI
  module Command
    class ValidateCommand < Command
      class << self
        def available_options
          [
            Configuration::Option.new(
              name: :domains,
              description: "Comma-separated list of domains to validate (Branch domains or non-Branch domains)",
              type: Array,
              example: "example.com,www.example.com",
              aliases: "-D"
            ),
            Configuration::Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to update",
              type: String,
              example: "MyProject.xcodeproj"
            ),
            Configuration::Option.new(
              name: :target,
              description: "Name of a target to validate in the Xcode project",
              type: String,
              example: "MyAppTarget"
            )
          ]
        end
      end

      def run!
        valid = true

        unless options.domains.nil? || options.domains.empty?
          domains_valid = helper.validate_project_domains(options.domains)

          if domains_valid
            say "Project domains match :domains parameter: ✅"
          else
            say "Project domains do not match specified :domains"
            helper.errors.each { |error| say " #{error}" }
          end

          valid &&= domains_valid
        end

        configuration_valid = helper.validate_team_and_bundle_ids_from_aasa_files
        unless configuration_valid
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
        end

        valid &&= configuration_valid

        say "Universal Link configuration passed validation. ✅" if valid

        valid
      end
    end
  end
end
