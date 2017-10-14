require "xcodeproj"

module BranchIOCLI
  class Command
    class << self
      def setup(options)
        @domains = all_domains options
        @keys = keys options

        if @keys.empty?
          say "Please specify --live_key or --test_key or both."
          return
        end

        if @domains.empty?
          say "Please specify --app_link_subdomain or --domains or both."
          return
        end

        @xcodeproj_path = xcodeproj_path options
        unless path
          say "Please specify the --xcodeproj option."
          return
        end

        # raises
        xcodeproj = Xcodeproj::Project.open @xcodeproj_path

        update_podfile(params) || update_cartfile(params, xcodeproj)

        target = options.target # may be nil

        if options.no_validate &&
           helper.validate_team_and_bundle_ids_from_aasa_files(xcodeproj, target, domains, params[:remove_existing_domains])
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return unless options.force
        else
          say "Universal Link configuration passed validation. ✅"
        end

        # the following calls can all raise IOError
        helper.add_keys_to_info_plist xcodeproj, target, keys
        helper.add_branch_universal_link_domains_to_info_plist xcodeproj, target, domains
        new_path = helper.add_universal_links_to_project xcodeproj, target, domains, false
        `git add #{new_path}` if options.commit && new_path

        helper.add_system_frameworks xcodeproj, target, options.frameworks unless options.frameworks.nil? || options.frameworks.empty?

        xcodeproj.save

        patch_source xcodeproj unless options.no_patch_source

        return unless options.commit

        `git commit #{helper.changes.join(" ")} -m '[branch_io_cli] Branch SDK integration'`
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

      def app_link_subdomains(options)
        app_link_subdomain = options.app_link_subdomain
        live_key = options.live_key
        test_key = options.test_key
        return [] if live_key.nil? and test_key.nil?
        return [] if app_link_subdomain.nil?

        domains = []
        unless live_key.nil?
          domains += [
            "#{app_link_subdomain}.app.link",
            "#{app_link_subdomain}-alternate.app.link"
          ]
        end
        unless test_key.nil?
          domains += [
            "#{app_link_subdomain}.test-app.link",
            "#{app_link_subdomain}-alternate.test-app.link"
          ]
        end
        domains
      end

      def all_domains(options)
        app_link_subdomains = app_link_subdomains params
        custom_domains = options.domains || []
        (app_link_subdomains + custom_domains).uniq
      end

      def keys(options)
        live_key = params[:live_key]
        test_key = params[:test_key]
        keys = {}
        keys[:live] = live_key unless live_key.nil?
        keys[:test] = test_key unless test_key.nil?
        keys
      end

      def podfile_path(options)
        # Disable Podfile update if add_sdk: false is present
        return nil if options.no_add_sdk

        # Use the :podfile parameter if present
        if options.podfile
          raise "--podfile argument must specify a path ending in '/Podfile'" unless options.podfile =~ %r{/Podfile$}
          podfile_path = File.expand_path options.podfile, "."
          return podfile_path if File.exist? podfile_path
          raise "#{podfile_path} not found"
        end

        # Look in the same directory as the project (typical setup)
        podfile_path = File.expand_path "../Podfile", @xcodeproj_path
        return podfile_path if File.exist? podfile_path
      end

      def cartfile_path(options)
        # Disable Cartfile update if add_sdk: false is present
        return nil if options.no_add_sdk

        # Use the :cartfile parameter if present
        if options.cartfile
          raise "--cartfile argument must specify a path ending in '/Cartfile'" unless options.cartfile =~ %r{/Cartfile$}
          cartfile_path = File.expand_path options.cartfile, "."
          return cartfile_path if File.exist? cartfile_path
          raise "#{cartfile_path} not found"
        end

        # Look in the same directory as the project (typical setup)
        cartfile_path = File.expand_path "../Cartfile", @xcodeproj_path
        return cartfile_path if File.exist? cartfile_path
      end

      def update_podfile(options)
        podfile_path = podfile_path options
        return false if podfile_path.nil?

        # 1. Patch Podfile. Return if no change (Branch pod already present).
        return false unless helper.patch_podfile podfile_path

        # 2. pod install
        command = 'pod install'
        command += ' --repo_update' unless options.no_pod_repo_update

        Dir.chdir(File.dirname(podfile_path)) do
          `#{command}`
        end

        # 3. Add Podfile and Podfile.lock to commit (in case :commit param specified)
        helper.add_change podfile_path
        helper.add_change "#{podfile_path}.lock"

        # 4. Check if Pods folder is under SCM
        pods_folder_path = File.expand_path "../Pods", podfile_path
        `git ls-files #{pods_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 5. If so, add the Pods folder to the commit (in case :commit param specified)
        helper.add_change pods_folder_path
        other_action.git_add path: pods_folder_path if options.commit
        true
      end

      def update_cartfile(options, project)
        cartfile_path = cartfile_path options
        return false if cartfile_path.nil?

        # 1. Patch Cartfile. Return if no change (Branch already present).
        return false unless helper.patch_cartfile cartfile_path

        # 2. carthage update
        Dir.chdir(File.dirname(cartfile_path)) do
          `carthage update`
        end

        # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
        helper.add_change cartfile_path
        helper.add_change "#{cartfile_path}.resolved"

        # 4. Add to target depependencies
        frameworks_group = project['Frameworks']
        branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
        target = helper.target_from_project project, options.target
        target.frameworks_build_phase.add_file_reference branch_framework

        # 5. Add to copy-frameworks build phase
        carthage_build_phase = target.build_phases.find do |phase|
          phase.respond_to?(:shell_script) && phase.shell_script =~ /carthage\s+copy-frameworks/
        end

        if carthage_build_phase
          carthage_build_phase.input_paths << "$(SRCROOT)/Carthage/Build/iOS/Branch.framework"
          carthage_build_phase.output_paths << "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Branch.framework"
        end

        # 6. Check if Carthage folder is under SCM
        carthage_folder_path = File.expand_path "../Carthage", cartfile_path
        `git ls-files #{carthage_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 7. If so, add the Pods folder to the commit (in case :commit param specified)
        helper.add_change carthage_folder_path
        other_action.git_add path: carthage_folder_path if options.commit
        true
      end

      def patch_source(xcodeproj)
        helper.patch_app_delegate_swift(xcodeproj) || helper.patch_app_delegate_objc(xcodeproj)
      end
    end
  end
end
