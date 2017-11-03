require "cocoapods-core"

module BranchIOCLI
  module Commands
    class ReportCommand < Command
      def initialize(options)
        super
        config_helper.validate_report_options options
      end

      def run!
        say "\n"

        if config_helper.header_only
          say report_header
          exit 0
        end

        File.open config_helper.report_path, "w" do |report|
          report.write "Branch.io Xcode build report v #{VERSION} #{DateTime.now}\n\n"
          report.write "#{report_configuration}\n"
          report.write "#{report_header}\n"

          # run xcodebuild -list
          report.report_command "#{base_xcodebuild_cmd} -list"

          # If using a workspace, -list all the projects as well
          if config_helper.workspace_path
            config_helper.workspace.file_references.map(&:path).each do |project_path|
              path = File.join File.dirname(config_helper.workspace_path), project_path
              report.report_command "xcodebuild -list -project #{path}"
            end
          end

          base_cmd = base_xcodebuild_cmd
          # Add -scheme option for the rest of the commands if using a workspace
          base_cmd = "#{base_cmd} -scheme #{config_helper.scheme}" if config_helper.workspace_path

          # xcodebuild -showBuildSettings
          report.report_command "#{base_cmd} -showBuildSettings"

          # Add more options for the rest of the commands
          base_cmd = "#{base_cmd} -configuration #{config_helper.configuration} -sdk #{config_helper.sdk}"
          base_cmd = "#{base_cmd} -target #{config_helper.target}" unless config_helper.workspace_path

          if config_helper.clean
            say "Cleaning"
            report.report_command "#{base_cmd} clean"
          end

          say "Building"
          report.report_command "#{base_cmd} -verbose"

          say "Done ✅"
        end

        say "Report generated in #{config_helper.report_path}"
      end

      def base_xcodebuild_cmd
        cmd = "xcodebuild"
        if config_helper.workspace_path
          cmd = "#{cmd} -workspace #{config_helper.workspace_path}"
        else
          cmd = "#{cmd} -project #{config_helper.xcodeproj_path}"
        end
        cmd
      end

      def branch_version
        version_from_podfile_lock ||
          version_from_cartfile_resolved ||
          version_from_branch_framework ||
          version_from_bnc_config_m
      end

      def requirement_from_podfile
        return nil unless config_helper.podfile_path
        podfile = File.read config_helper.podfile_path
        matches = /\n?\s*pod\s+("Branch"|'Branch').*?\n/m.match podfile
        matches ? matches[0].strip : nil
      end

      def requirement_from_cartfile
        return nil unless config_helper.cartfile_path
        cartfile = File.read config_helper.cartfile_path
        matches = %r{^git(hub\s+"|\s+"https://github.com/)BranchMetrics/(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK.*?).*?\n}m.match cartfile
        matches ? matches[0].strip : nil
      end

      def version_from_podfile_lock
        return nil unless config_helper.podfile_path && File.exist?("#{config_helper.podfile_path}.lock")
        podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config_helper.podfile_path}.lock"
        version = podfile_lock.version "Branch"

        version ? "#{version} [Podfile.lock]" : nil
      end

      def version_from_cartfile_resolved
        return nil unless config_helper.cartfile_path && File.exist?("#{config_helper.cartfile_path}.resolved")
        cartfile_resolved = File.read "#{config_helper.cartfile_path}.resolved"

        # Matches:
        # git "https://github.com/BranchMetrics/ios-branch-deep-linking"
        # git "https://github.com/BranchMetrics/ios-branch-deep-linking/"
        # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
        # git "https://github.com/BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
        # github "BranchMetrics/ios-branch-deep-linking"
        # github "BranchMetrics/ios-branch-deep-linking/"
        # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK"
        # github "BranchMetrics/iOS-Deferred-Deep-Linking-SDK/"
        matches = %r{(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK)/?" "(\d+\.\d+\.\d+)"}m.match cartfile_resolved
        return nil unless matches
        version = matches[2]
        "#{version} [Cartfile.resolved]"
      end

      def version_from_branch_framework
        framework = config_helper.target.frameworks_build_phase.files.find { |f| f.file_ref.path =~ /Branch.framework$/ }
        return nil unless framework
        framework_path = framework.file_ref.real_path
        info_plist_path = File.join framework_path.to_s, "Info.plist"
        return nil unless File.exist? info_plist_path

        require "cfpropertylist"

        raw_info_plist = CFPropertyList::List.new file: info_plist_path
        info_plist = CFPropertyList.native_types raw_info_plist.value
        version = info_plist["CFBundleVersion"]
        version ? "#{version} [Branch.framework/Info.plist]" : nil
      end

      def version_from_bnc_config_m
        # Look for BNCConfig.m in embedded source
        bnc_config_m_ref = config_helper.xcodeproj.files.find { |f| f.path =~ /BNCConfig\.m$/ }
        return nil unless bnc_config_m_ref
        bnc_config_m = File.read bnc_config_m_ref.real_path
        matches = /BNC_SDK_VERSION\s+=\s+@"(\d+\.\d+\.\d+)"/m.match bnc_config_m
        return nil unless matches
        version = matches[1]
        "#{version} [BNCConfig.m]"
      end

      def report_configuration
        <<EOF
Configuration:

Xcode workspace: #{config_helper.workspace_path || '(none)'}
Xcode project: #{config_helper.xcodeproj_path || '(none)'}
Scheme: #{config_helper.scheme || '(none)'}
Target: #{config_helper.target || '(none)'}
Configuration: #{config_helper.configuration || '(none)'}
SDK: #{config_helper.sdk}
Podfile: #{config_helper.podfile_path || '(none)'}
Cartfile: #{config_helper.cartfile_path || '(none)'}
Clean: #{config_helper.clean.inspect}
EOF
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def report_header
        header = `xcodebuild -version`

        header += "\nTarget #{config_helper.target.name} deploy target: #{config_helper.target.deployment_target}\n"

        if config_helper.podfile_path
          begin
            cocoapods_version = `pod --version`.chomp
          rescue Errno::ENOENT
            header += "\n(pod command not found)\n"
          end

          if File.exist?("#{config_helper.podfile_path}.lock")
            podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config_helper.podfile_path}.lock"
          end

          if cocoapods_version || podfile_lock
            header += "\nUsing CocoaPods v. "
            if cocoapods_version
              header += "#{cocoapods_version} (CLI) "
            end
            if podfile_lock
              header += "#{podfile_lock.cocoapods_version} (Podfile.lock)"
            end
            header += "\n"
          end

          # Already verified existence.
          podfile = Pod::Podfile.from_file Pathname.new config_helper.podfile_path
          target_definition = podfile.target_definition_list.find { |t| t.name == config_helper.target.name }
          if target_definition
            branch_dep = target_definition.dependencies.find { |p| p.name == "Branch" }
            header += "Podfile target #{target_definition.name}:"
            header += "\n use_frameworks!" if target_definition.uses_frameworks?
            header += "\n platform: #{target_definition.platform}"
            header += "\n build configurations: #{target_definition.build_configurations}"
            header += "\n inheritance: #{target_definition.inheritance}"
            header += "\n pod 'Branch', '#{branch_dep.requirement}'" if branch_dep
            header += ", #{branch_dep.external_source}" if branch_dep && branch_dep.external_source
            header += "\n"
          else
            header += "Target #{config_helper.target.name.inspect} not found in Podfile.\n"
          end

        end

        if config_helper.cartfile_path
          begin
            carthage_version = `carthage version`.chomp
            header += "\nUsing Carthage v. #{carthage_version}\n"
          rescue Errno::ENOENT
            header += "\n(carthage command not found)\n"
          end
        end

        cartfile_requirement = requirement_from_cartfile
        header += "\nFrom Cartfile:\n#{cartfile_requirement}\n" if cartfile_requirement

        version = branch_version
        if version
          header += "\nBranch SDK v. #{version}\n"
        else
          header += "\nBranch SDK not found.\n"
        end

        header
      end
      # rubocop: enable Metrics/PerceivedComplexity
    end
  end
end
