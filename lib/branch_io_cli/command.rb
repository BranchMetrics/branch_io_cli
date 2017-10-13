require "xcodeproj"

module BranchIOCLI
  class Command
    class << self
      def setup(options)
        # TODO: Rebuild the SetupBranchAction here
      end

      def validate(options)
        path = xcodeproj_path options
        unless path
          say "Please specify the --xcodeproj option."
          return
        end

        # raises
        xcodeproj = Xcodeproj::Project.open path

        valid = true

        unless options.domains.nil? || options.domains.empty?
          domains_valid = helper.validate_project_domains(
            options.domains,
            xcodeproj,
            options.target
          )

          if domains_valid
            say "Project domains match :domains parameter: ✅"
          else
            say "Project domains do not match specified :domains"
            helper.errors.each { |error| say " #{error}" }
          end

          valid &&= domains_valid
        end

        configuration_valid = helper.validate_team_and_bundle_ids_from_aasa_files xcodeproj, options.target
        unless configuration_valid
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
        end

        valid &&= configuration_valid

        say "Universal Link configuration passed validation. ✅" if valid

        # TODO: Return an exit code from the CLI indicating success or failure.
        # e.g. if not valid
        # $ branch_io validate
        # $ echo $?
        # 1
        # if valid
        # $ branch_io validate
        # $ echo $?
        # 0
      end

      def helper
        BranchIOCLI::Helper::BranchHelper
      end

      def xcodeproj_path(options)
        return options.xcodeproj if options.xcodeproj

        repo_path = "."

        all_xcodeproj_paths = Dir[File.expand_path(File.join(repo_path, '**/*.xcodeproj'))]
        # find an xcodeproj (ignoring the Pods and Carthage folders)
        # TODO: Improve this filter
        xcodeproj_paths = all_xcodeproj_paths.reject { |p| p =~ /Pods|Carthage/ }

        # no projects found: error
        say 'Could not find a .xcodeproj in the current repository\'s working directory.' and return nil if xcodeproj_paths.count == 0

        # too many projects found: error
        if xcodeproj_paths.count > 1
          repo_pathname = Pathname.new repo_path
          relative_projects = xcodeproj_paths.map { |e| Pathname.new(e).relative_path_from(repo_pathname).to_s }.join("\n")
          say "Found multiple .xcodeproj projects in the current repository's working directory. Please specify your app's main project: \n#{relative_projects}"
          return nil
        end

        # one project found: great
        xcodeproj_paths.first
      end
    end
  end
end
