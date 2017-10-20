require "pathname"
require "xcodeproj"

module BranchIOCLI
  class Command
    class << self
      def setup(options)
        config_helper.validate_setup_options options

        @keys = config_helper.keys
        @domains = config_helper.all_domains
        @xcodeproj_path = config_helper.xcodeproj_path
        xcodeproj = config_helper.xcodeproj

        update_podfile(options) || update_cartfile(options, xcodeproj)

        target_name = options.target # may be nil
        is_app_target = !ConfigurationHelper.target.extension_target_type?

        if is_app_target && !options.no_validate &&
           !helper.validate_team_and_bundle_ids_from_aasa_files(xcodeproj, target_name, @domains)
          say "Universal Link configuration failed validation."
          helper.errors.each { |error| say " #{error}" }
          return unless options.force
        elsif is_app_target && !options.no_validate
          say "Universal Link configuration passed validation. ✅"
        end

        # the following calls can all raise IOError
        helper.add_keys_to_info_plist xcodeproj, target_name, @keys
        helper.add_branch_universal_link_domains_to_info_plist xcodeproj, target_name, @domains if is_app_target
        new_path = helper.add_universal_links_to_project xcodeproj, target_name, @domains, false if is_app_target
        `git add #{new_path}` if options.commit && new_path

        helper.add_system_frameworks xcodeproj, target_name, options.frameworks unless options.frameworks.nil? || options.frameworks.empty?

        xcodeproj.save

        patch_source xcodeproj unless options.no_patch_source

        return unless options.commit

        current_pathname = Pathname.new File.expand_path "."
        changes = helper.changes.to_a.map { |c| Pathname.new(File.expand_path(c)).relative_path_from(current_pathname).to_s }

        `git commit #{changes.join(" ")} -m '[branch_io_cli] Branch SDK integration'`
      end

      def validate(options)
        config_helper.validate_validation_options options

        # raises
        xcodeproj = config_helper.xcodeproj

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

        valid
      end

      def helper
        Helper::BranchHelper
      end

      def config_helper
        Helper::ConfigurationHelper
      end

      def update_podfile(options)
        podfile_path = config_helper.podfile_path
        return false if podfile_path.nil?

        # 1. Patch Podfile. Return if no change (Branch pod already present).
        return false unless helper.patch_podfile podfile_path

        # 2. pod install
        # command = "PATH='#{ENV['PATH']}' pod install"
        command = 'pod install'
        command += ' --repo-update' unless options.no_pod_repo_update

        Dir.chdir(File.dirname(podfile_path)) do
          system command
        end

        # 3. Add Podfile and Podfile.lock to commit (in case :commit param specified)
        helper.add_change podfile_path
        helper.add_change "#{podfile_path}.lock"

        # 4. Check if Pods folder is under SCM
        current_pathname = Pathname.new File.expand_path "."
        pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from current_pathname
        `git ls-files #{pods_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 5. If so, add the Pods folder to the commit (in case :commit param specified)
        helper.add_change pods_folder_path
        `git add #{pods_folder_path}` if options.commit

        true
      end

      def update_cartfile(options, project)
        cartfile_path = config_helper.cartfile_path
        return false if cartfile_path.nil?

        # 1. Patch Cartfile. Return if no change (Branch already present).
        return false unless helper.patch_cartfile cartfile_path

        # 2. carthage update
        Dir.chdir(File.dirname(cartfile_path)) do
          system "carthage update --platform ios"
        end

        # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
        helper.add_change cartfile_path
        helper.add_change "#{cartfile_path}.resolved"

        # 4. Add to target depependencies
        frameworks_group = project.frameworks_group
        branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
        target = ConfigurationHelper.target
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
        current_pathname = Pathname.new File.expand_path "."
        carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from current_pathname
        `git ls-files #{carthage_folder_path} --error-unmatch > /dev/null 2>&1`
        return true unless $?.exitstatus == 0

        # 7. If so, add the Carthage folder to the commit (in case :commit param specified)
        helper.add_change carthage_folder_path
        `git add #{carthage_folder_path}` if options.commit

        true
      end

      def patch_source(xcodeproj)
        helper.patch_app_delegate_swift(xcodeproj) || helper.patch_app_delegate_objc(xcodeproj)
      end
    end
  end
end
