require "cocoapods-core"
require "cfpropertylist"

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
          report.write "Branch.io Xcode build report v #{VERSION}\n\n"
          # TODO: Write out command-line options or configuration from helper
          report.write "#{report_header}\n"

          if config_helper.clean
            say "Cleaning"
            clean_cmd = "#{base_xcodebuild_cmd} clean"
            report.write "$ #{clean_cmd}\n\n"
            report.write `#{clean_cmd}`
          end

          say "Building"
          build_cmd = "#{base_xcodebuild_cmd} -verbose"
          report.write "$ #{build_cmd}\n\n"
          report.write `#{build_cmd}`

          say "Done ✅"
        end
        say "Report generated in #{config_helper.report_path}"
      end

      def base_xcodebuild_cmd
        cmd = "xcodebuild"
        cmd = "#{cmd} -scheme #{config_helper.scheme}" if config_helper.scheme
        cmd = "#{cmd} -workspace #{config_helper.workspace_path}" if config_helper.workspace_path
        cmd = "#{cmd} -project #{config_helper.xcodeproj_path}" if config_helper.xcodeproj_path && !config_helper.workspace_path
        cmd = "#{cmd} -target #{config_helper.target}" if config_helper.target
        cmd = "#{cmd} -configuration #{config_helper.configuration}" if config_helper.configuration
        cmd
      end

      def branch_version
        version_from_podfile_lock ||
          version_from_cartfile_resolved ||
          version_from_branch_framework ||
          version_from_bnc_config_m
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
        framework = config_helper.xcodeproj.frameworks_group.files.find { |f| f.path =~ /Branch.framework$/ }
        return nil unless framework
        framework_path = framework.real_path
        info_plist_path = File.join framework_path.to_s, "Info.plist"
        return nil unless File.exist? info_plist_path

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

      def report_header
        header = `xcodebuild -version`
        version = branch_version
        if version
          header = "#{header}\nBranch SDK v. #{version}"
        else
          header = "Branch SDK not found"
        end
        "#{header}\n"
      end
    end
  end
end
