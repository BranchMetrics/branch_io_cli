require "pathname"
require "xcodeproj"

module BranchIOCLI
  class Command
    def run(options)
      # implemented by subclasses
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
      command += ' --repo-update' if options.pod_repo_update

      Dir.chdir(File.dirname(podfile_path)) do
        system command
      end

      # 3. Add Podfile and Podfile.lock to commit (in case :commit param specified)
      helper.add_change podfile_path
      helper.add_change "#{podfile_path}.lock"

      # 4. Check if Pods folder is under SCM
      pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
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

      # 4. Add to target dependencies
      frameworks_group = project.frameworks_group
      branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
      target = Helper::ConfigurationHelper.target
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
      carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from Pathname.pwd
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
