require "cocoapods-core"
require "fileutils"
require "pathname"
require "pattern_patch"
require "zip"

module BranchIOCLI
  module Helper
    class ToolHelper
      extend Methods

      class << self
        def config
          Configuration::Configuration.current
        end

        def helper
          BranchHelper
        end

        def add_cocoapods(options)
          verify_cocoapods

          podfile_path = options.podfile_path

          install_command = "pod install"
          install_command += " --repo-update" if options.pod_repo_update
          Dir.chdir(File.dirname(podfile_path)) do
            sh "pod init"
            PatternPatch::Patch.new(
              regexp: /^(\s*)# Pods for #{options.target.name}$/,
              mode: :append,
              text: "\n\\1pod \"Branch\""
            ).apply podfile_path
            # Store a Pod::Podfile representation of this file.
            options.open_podfile
            sh install_command
          end

          return unless options.commit

          helper.add_change podfile_path
          helper.add_change "#{podfile_path}.lock"

          # For now, add Pods folder to SCM.
          pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
          workspace_path = Pathname.new(File.expand_path(options.xcodeproj_path.sub(/.xcodeproj$/, ".xcworkspace"))).relative_path_from Pathname.pwd
          podfile_pathname = Pathname.new(podfile_path).relative_path_from Pathname.pwd
          helper.add_change pods_folder_path
          helper.add_change workspace_path

          sh(
            "git",
            "add",
            podfile_pathname.to_s,
            "#{podfile_pathname}.lock",
            pods_folder_path.to_s,
            workspace_path.to_s
          )
        end

        def add_carthage(options)
          # TODO: Collapse this and Command::update_cartfile
          verify_carthage

          # 1. Generate Cartfile
          cartfile_path = options.cartfile_path
          File.open(cartfile_path, "w") do |file|
            file.write <<-EOF
github "BranchMetrics/ios-branch-deep-linking"
            EOF
          end

          # 2. carthage update
          sh "carthage #{options.carthage_command}", chdir: File.dirname(config.cartfile_path)

          # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
          helper.add_change cartfile_path
          helper.add_change "#{cartfile_path}.resolved"
          helper.add_change options.xcodeproj_path

          # 4. Add to target dependencies
          frameworks_group = options.xcodeproj.frameworks_group
          branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
          target = options.target
          target.frameworks_build_phase.add_file_reference branch_framework

          # 5. Create a copy-frameworks build phase
          carthage_build_phase = target.new_shell_script_build_phase "carthage copy-frameworks"
          carthage_build_phase.shell_script = "/usr/local/bin/carthage copy-frameworks"

          carthage_build_phase.input_paths << "$(SRCROOT)/Carthage/Build/iOS/Branch.framework"
          carthage_build_phase.output_paths << "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Branch.framework"

          update_framework_search_paths "$(SRCROOT)/Carthage/Build/iOS"

          options.xcodeproj.save

          return unless options.commit

          # For now, add Carthage folder to SCM

          # 6. Add the Carthage folder to the commit (in case :commit param specified)
          carthage_folder_path = Pathname.new(File.expand_path("../Carthage", cartfile_path)).relative_path_from(Pathname.pwd)
          cartfile_pathname = Pathname.new(cartfile_path).relative_path_from Pathname.pwd
          helper.add_change carthage_folder_path
          sh "git", "add", cartfile_pathname.to_s, "#{cartfile_pathname}.resolved", carthage_folder_path.to_s
        end

        def add_direct(options)
          # Put the framework in the path for any existing Frameworks group in the project.
          frameworks_group = options.xcodeproj.frameworks_group
          framework_path = File.join frameworks_group.real_path, "Branch.framework"
          raise "#{framework_path} exists." if File.exist? framework_path

          say "Finding current framework release"

          # Find the latest release from GitHub.
          releases = JSON.parse helper.fetch "https://api.github.com/repos/BranchMetrics/ios-branch-deep-linking/releases"
          current_release = releases.first
          # Get the download URL for the framework.
          framework_asset = current_release["assets"][0]
          framework_url = framework_asset["browser_download_url"]

          say "Downloading Branch.framework v. #{current_release['tag_name']} (#{framework_asset['size']} bytes zipped)"

          Dir.mktmpdir do |download_folder|
            zip_path = File.join download_folder, "Branch.framework.zip"

            File.unlink zip_path if File.exist? zip_path

            # Download the framework zip
            helper.download framework_url, zip_path

            say "Unzipping Branch.framework"

            # Unzip
            Zip::File.open zip_path do |zip_file|
              # Start with just the framework and add dSYM, etc., later
              zip_file.glob "Carthage/Build/iOS/Branch.framework/**/*" do |entry|
                filename = entry.name.sub %r{^Carthage/Build/iOS}, frameworks_group.real_path.to_s
                FileUtils.mkdir_p File.dirname filename
                entry.extract filename
              end
            end
          end

          # Now the current framework is in framework_path

          say "Adding to #{options.xcodeproj_path}"

          # Add as a dependency in the Frameworks group
          framework = frameworks_group.new_file "Branch.framework" # relative to frameworks_group.real_path
          options.target.frameworks_build_phase.add_file_reference framework, true

          update_framework_search_paths "$(SRCROOT)"

          options.xcodeproj.save

          helper.add_change options.xcodeproj_path
          helper.add_change framework_path
          sh "git", "add", framework_path if options.commit
        end

        def update_framework_search_paths(path)
          # Make sure this is in the FRAMEWORK_SEARCH_PATHS if we just added it.
          if config.xcodeproj.frameworks_group.files.count == 1
            target = config.target
            target.build_configurations.each do |c|
              # this accounts for project-level settings as well
              setting = target.resolved_build_setting("FRAMEWORK_SEARCH_PATHS")[c.name] || []
              next if setting.include?(path) || setting.include?("#{path}/**")
              setting << path

              c.build_settings["FRAMEWORK_SEARCH_PATHS"] = setting
            end
          end
          # If it already existed, it's almost certainly already in FRAMEWORK_SEARCH_PATHS.
        end

        def update_podfile(options)
          verify_cocoapods

          podfile_path = options.podfile_path
          return false if podfile_path.nil?

          # 1. Patch Podfile. Return if no change (Branch pod already present).
          return false unless PatchHelper.patch_podfile podfile_path

          # 2. pod install
          # command = "PATH='#{ENV['PATH']}' pod install"
          command = 'pod install'
          command += ' --repo-update' if options.pod_repo_update

          sh command, chdir: File.dirname(config.podfile_path)

          # 3. Add Podfile and Podfile.lock to commit (in case :commit param specified)
          helper.add_change podfile_path
          helper.add_change "#{podfile_path}.lock"

          # 4. Check if Pods folder is under SCM
          pods_folder_path = Pathname.new(File.expand_path("../Pods", podfile_path)).relative_path_from Pathname.pwd
          `git ls-files #{pods_folder_path.to_s.shellescape} --error-unmatch > /dev/null 2>&1`
          return true unless $?.exitstatus == 0

          # 5. If so, add the Pods folder to the commit (in case :commit param specified)
          helper.add_change pods_folder_path
          sh "git", "add", pods_folder_path.to_s if options.commit

          true
        end

        def update_cartfile(options, project)
          verify_carthage

          cartfile_path = options.cartfile_path
          return false if cartfile_path.nil?

          # 1. Patch Cartfile. Return if no change (Branch already present).
          return false unless PatchHelper.patch_cartfile cartfile_path

          # 2. carthage bootstrap (or other command)
          cmd = "carthage #{options.carthage_command}"
          cmd << " ios-branch-deep-linking" if options.carthage_command =~ /^(update|build)/
          sh cmd, chdir: File.dirname(config.cartfile_path)

          # 3. Add Cartfile and Cartfile.resolved to commit (in case :commit param specified)
          helper.add_change cartfile_path
          helper.add_change "#{cartfile_path}.resolved"
          helper.add_change options.xcodeproj_path

          # 4. Add to target dependencies
          frameworks_group = project.frameworks_group
          branch_framework = frameworks_group.new_file "Carthage/Build/iOS/Branch.framework"
          target = options.target
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
          `git ls-files #{carthage_folder_path.to_s.shellescape} --error-unmatch > /dev/null 2>&1`
          return true unless $?.exitstatus == 0

          # 7. If so, add the Carthage folder to the commit (in case :commit param specified)
          helper.add_change carthage_folder_path
          sh "git", "add", carthage_folder_path.to_s if options.commit

          true
        end

        def verify_cocoapods
          pod_cmd = `which pod`
          return unless pod_cmd.empty?

          gem_cmd = `which gem`
          if gem_cmd.empty?
            say "'pod' command not available in PATH and 'gem' command not available in PATH to install cocoapods."
            exit(-1)
          end

          install = confirm "'pod' command not available in PATH. Install cocoapods (may require a sudo password)?", true
          unless install
            say "Please install cocoapods or use --no-add-sdk to continue."
            exit(-1)
          end

          gem_home = Gem.dir
          if gem_home && File.writable?(gem_home)
            sh "gem install cocoapods"
          else
            sh "sudo gem install cocoapods"
          end

          # Ensure master podspec repo is set up (will update if it exists).
          sh "pod setup"
        end

        def verify_carthage
          carthage_cmd = `which carthage`
          return unless carthage_cmd.empty?

          brew_cmd = `which brew`
          if brew_cmd.empty?
            say "'carthage' command not available in PATH and 'brew' command not available in PATH to install 'carthage'."
            exit(-1)
          end

          install = confirm "'carthage' command not available in PATH. Use Homebrew to install carthage?", true
          unless install
            say "Please install carthage or use --no-add-sdk to continue."
            exit(-1)
          end

          sh "brew install carthage"
        end

        def verify_git
          return unless config.commit

          git_cmd = `which git`
          return unless git_cmd.empty?

          xcode_select_path = `which xcode-select`
          if xcode_select_path.empty?
            say "'git' command not available in PATH and 'xcode-select' command not available in PATH to install 'git'."
            exit(-1)
          end

          install = confirm "'git' command not available in PATH. Install Xcode command-line tools (requires password)?", true
          unless install
            say "Please install Xcode command tools or leave out the --commit option to continue."
            exit(-1)
          end

          sh "xcode-select --install"
        end
      end
    end
  end
end
