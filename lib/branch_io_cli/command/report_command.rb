require "cocoapods-core"
require "branch_io_cli/helper/methods"
require "open3"
require "plist"
require "xcodeproj"

module BranchIOCLI
  module Command
    class ReportCommand < Command
      def initialize(options)
        super
        @config = Configuration::ReportConfiguration.new options
      end

      def run!
        say "\n"

        unless load_settings_from_xcode
          say "Failed to load settings from Xcode. Some information may be missing.\n"
        end

        if config.header_only
          say report_header
          exit 0
        end

        # Only if a Podfile is detected/supplied at the command line.
        if pod_install_required?
          say "pod install required in order to build."
          install = ask %{Run "pod install" now (Y/n)? }
          if install.downcase =~ /^n/
            say %{Please run "pod install" or "pod update" first in order to continue.}
            exit(-1)
          end

          helper.verify_cocoapods

          install_command = "pod install"

          if config.pod_repo_update
            install_command += " --repo-update"
          else
            say <<EOF
You have disabled "pod repo update". This can cause "pod install" to fail in
some cases. If that happens, please rerun without --no-pod-repo-update or run
"pod install --repo-update" manually.
EOF
          end

          sh install_command
        end

        File.open config.report_path, "w" do |report|
          report.write "Branch.io Xcode build report v #{VERSION} #{DateTime.now}\n\n"
          report.write "#{report_configuration}\n"
          report.write "#{report_header}\n"

          # run xcodebuild -list
          report.log_command "#{base_xcodebuild_cmd} -list"

          # If using a workspace, -list all the projects as well
          if config.workspace_path
            config.workspace.file_references.map(&:path).each do |project_path|
              path = File.join File.dirname(config.workspace_path), project_path
              report.log_command "xcodebuild -list -project #{path}"
            end
          end

          base_cmd = base_xcodebuild_cmd
          # Add -scheme option for the rest of the commands if using a workspace
          base_cmd = "#{base_cmd} -scheme #{config.scheme}" if config.workspace_path

          # xcodebuild -showBuildSettings
          report.write "$ #{base_cmd} -showBuildSettings\n\n"
          report.write @xcodebuild_showbuildsettings_output
          if @xcodebuild_showbuildsettings_status.success?
            report.write "Success.\n\n"
          else
            report.write "#{@xcodebuild_showbuildsettings_status}.\n\n"
          end

          # Add more options for the rest of the commands
          base_cmd = "#{base_cmd} -configuration #{config.configuration} -sdk #{config.sdk}"
          base_cmd = "#{base_cmd} -target #{config.target}" unless config.workspace_path

          if config.clean
            say "Cleaning"
            report.log_command "#{base_cmd} clean"
          end

          say "Building"
          report.log_command "#{base_cmd} -verbose"

          say "Done ✅"
        end

        say "Report generated in #{config.report_path}"
      end

      def base_xcodebuild_cmd
        cmd = "xcodebuild"
        if config.workspace_path
          cmd = "#{cmd} -workspace #{config.workspace_path}"
        else
          cmd = "#{cmd} -project #{config.xcodeproj_path}"
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
        return nil unless config.podfile_path
        podfile = File.read config.podfile_path
        matches = /\n?\s*pod\s+("Branch"|'Branch').*?\n/m.match podfile
        matches ? matches[0].strip : nil
      end

      def requirement_from_cartfile
        return nil unless config.cartfile_path
        cartfile = File.read config.cartfile_path
        matches = %r{^git(hub\s+"|\s+"https://github.com/)BranchMetrics/(ios-branch-deep-linking|iOS-Deferred-Deep-Linking-SDK.*?).*?\n}m.match cartfile
        matches ? matches[0].strip : nil
      end

      def version_from_podfile_lock
        return nil unless config.podfile_path && File.exist?("#{config.podfile_path}.lock")
        podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config.podfile_path}.lock"
        version = podfile_lock.version("Branch") || podfile_lock.version("Branch-SDK")

        version ? "#{version} [Podfile.lock]" : nil
      end

      def version_from_cartfile_resolved
        return nil unless config.cartfile_path && File.exist?("#{config.cartfile_path}.resolved")
        cartfile_resolved = File.read "#{config.cartfile_path}.resolved"

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
        framework = config.target.frameworks_build_phase.files.find { |f| f.file_ref.path =~ /Branch.framework$/ }
        return nil unless framework
        if framework.file_ref.isa == "PBXFileReference"
          framework_path = framework.file_ref.real_path
        elsif framework.file_ref.isa == "PBXReferenceProxy" && @xcode_settings
          framework_path = File.expand_path framework.file_ref.path, @xcode_settings[framework.file_ref.source_tree]
        end
        info_plist_path = File.join framework_path.to_s, "Info.plist"
        return nil unless File.exist? info_plist_path

        require "cfpropertylist"

        raw_info_plist = CFPropertyList::List.new file: info_plist_path
        info_plist = CFPropertyList.native_types raw_info_plist.value
        version = info_plist["CFBundleVersion"]
        version ? "#{version} [Branch.framework/Info.plist]" : nil
      end

      def version_from_bnc_config_m(project = @config.xcodeproj)
        # Look for BNCConfig.m in embedded source
        bnc_config_m_ref = project.files.find { |f| f.path =~ /BNCConfig\.m$/ }
        unless bnc_config_m_ref
          subprojects = project.files.select { |f| f.path =~ /\.xcodeproj$/ }
          subprojects.each do |subproject|
            p = Xcodeproj::Project.open subproject.real_path
            version = version_from_bnc_config_m p
            return version if version
          end
        end

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

Xcode workspace: #{config.workspace_path || '(none)'}
Xcode project: #{config.xcodeproj_path || '(none)'}
Scheme: #{config.scheme || '(none)'}
Target: #{config.target || '(none)'}
Configuration: #{config.configuration || '(none)'}
SDK: #{config.sdk}
Podfile: #{config.podfile_path || '(none)'}
Cartfile: #{config.cartfile_path || '(none)'}
Pod repo update: #{config.pod_repo_update.inspect}
Clean: #{config.clean.inspect}
EOF
      end

      def pod_install_required?
        # If this is set, its existence has been verified.
        return false unless config.podfile_path

        lockfile_path = "#{config.podfile_path}.lock"
        manifest_path = File.expand_path "../Pods/Manifest.lock", config.podfile_path

        return true unless File.exist?(lockfile_path) && File.exist?(manifest_path)

        lockfile = Pod::Lockfile.from_file Pathname.new lockfile_path
        manifest = Pod::Lockfile.from_file Pathname.new manifest_path

        # diff the contents of Podfile.lock and Pods/Manifest.lock
        # This is just what is done in the "[CP] Check Pods Manifest.lock" script build phase
        # in a project using CocoaPods.
        return true unless lockfile == manifest

        # compare checksum of Podfile with checksum in Podfile.lock
        # This is a good sanity check, but perhaps unnecessary. It means pod install
        # has not been run since the Podfile was modified, which is probably an oversight.
        return true unless lockfile.to_hash["PODFILE CHECKSUM"] == config.podfile.checksum

        false
      end

      # rubocop: disable Metrics/PerceivedComplexity
      def report_header
        header = "cocoapods-core: #{Pod::CORE_VERSION}\n"

        header += `xcodebuild -version`

        bundle_identifier = helper.expanded_build_setting config.target, "PRODUCT_BUNDLE_IDENTIFIER", config.configuration
        dev_team = helper.expanded_build_setting config.target, "DEVELOPMENT_TEAM", config.configuration
        infoplist_path = helper.expanded_build_setting config.target, "INFOPLIST_FILE", config.configuration
        entitlements_path = helper.expanded_build_setting config.target, "CODE_SIGN_ENTITLEMENTS", config.configuration

        header += "\nTarget #{config.target.name}:\n"
        header += " Bundle identifier: #{bundle_identifier || '(none)'}\n"
        header += " Development team: #{dev_team || '(none)'}\n"
        header += " Deployment target: #{config.target.deployment_target}\n"
        header += " Modules #{config.modules_enabled? ? '' : 'not '}enabled\n"
        header += " Swift #{config.swift_version}\n" if config.swift_version
        header += " Bridging header: #{config.bridging_header_path}\n" if config.bridging_header_path
        header += " Info.plist: #{infoplist_path || '(none)'}\n"
        header += " Entitlements file: #{entitlements_path || '(none)'}\n"

        if config.podfile_path
          begin
            cocoapods_version = `pod --version`.chomp
          rescue Errno::ENOENT
            header += "\n(pod command not found)\n"
          end

          if File.exist?("#{config.podfile_path}.lock")
            podfile_lock = Pod::Lockfile.from_file Pathname.new "#{config.podfile_path}.lock"
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

          target_definition = config.podfile.target_definitions[config.target.name]
          if target_definition
            branch_deps = target_definition.dependencies.select { |p| p.name =~ %r{^(Branch|Branch-SDK)(/.*)?$} }
            header += "Podfile target #{target_definition.name}:"
            header += "\n use_frameworks!" if target_definition.uses_frameworks?
            header += "\n platform: #{target_definition.platform}"
            header += "\n build configurations: #{target_definition.build_configurations}"
            header += "\n inheritance: #{target_definition.inheritance}"
            branch_deps.each do |dep|
              header += "\n pod '#{dep.name}', '#{dep.requirement}'"
              header += ", #{dep.external_source}" if dep.external_source
              header += "\n"
            end
          else
            header += "Target #{config.target.name.inspect} not found in Podfile.\n"
          end

          header += "\npod install #{pod_install_required? ? '' : 'not '}required.\n"
        end

        if config.cartfile_path
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

        header += "\n#{branch_report}"

        header
      end
      # rubocop: enable Metrics/PerceivedComplexity

      # String containing information relevant to Branch setup
      def branch_report
        infoplist_path = helper.expanded_build_setting config.target, "INFOPLIST_FILE", config.configuration

        report = "Branch configuration:\n"

        begin
          info_plist = File.open(infoplist_path) { |f| Plist.parse_xml f }
          branch_key = info_plist["branch_key"]
          report += " Branch key(s) (Info.plist):\n"
          if branch_key.kind_of? Hash
            branch_key.each_key do |key|
              report += "  #{key.capitalize}: #{branch_key[key]}\n"
            end
          elsif branch_key
            report += "  #{branch_key}\n"
          else
            report += "  (none found)\n"
          end

          branch_universal_link_domains = info_plist["branch_universal_link_domains"]
          if branch_universal_link_domains
            if branch_universal_link_domains.kind_of? Array
              report += " branch_universal_link_domains (Info.plist):\n"
              branch_universal_link_domains.each do |domain|
                report += "  #{domain}\n"
              end
            else
              report += " branch_universal_link_domains (Info.plist): #{branch_universal_link_domains}\n"
            end
          end
        rescue StandardError => e
          report += " (Failed to open Info.plist: #{e.message})\n"
        end

        unless config.target.extension_target_type?
          begin
            domains = helper.domains_from_project config.configuration
            report += " Universal Link domains (entitlements):\n"
            domains.each do |domain|
              report += "  #{domain}\n"
            end
          rescue StandardError => e
            report += " (Failed to get Universal Link domains from entitlements file: #{e.message})\n"
          end
        end

        report
      end

      def built_products_dir
        @xcode_settings["BUILT_PRODUCTS_DIR"]
      end

      def load_settings_from_xcode
        cmd = base_xcodebuild_cmd
        cmd = "#{cmd} -scheme #{config.scheme}" if config.workspace_path
        cmd = "#{cmd} -sdk #{config.sdk} -configuration #{config.configuration} -showBuildSettings"
        @xcodebuild_showbuildsettings_output = ""
        @xcode_settings = {}
        Open3.popen2e(cmd) do |stdin, output, thread|
          while (line = output.gets)
            @xcodebuild_showbuildsettings_output += line
            line.strip!
            next unless (matches = /^(.+)\s+=\s+(.+)$/.match line)
            @xcode_settings[matches[1]] = matches[2]
          end
          @xcodebuild_showbuildsettings_status = thread.value
          return @xcodebuild_showbuildsettings_status.success?
        end
      end
    end
  end
end
