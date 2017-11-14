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

        unless xcode_settings.valid?
          say "Failed to load settings from Xcode. Some information may be missing.\n"
        end

        if config.header_only
          say report_helper.report_header
          exit 0
        end

        # Only if a Podfile is detected/supplied at the command line.
        if config.pod_install_required?
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
          report.write "#{report_helper.report_configuration}\n"
          report.write "#{report_helper.report_header}\n"

          # run xcodebuild -list
          report.log_command "#{report_helper.base_xcodebuild_cmd} -list"

          # If using a workspace, -list all the projects as well
          if config.workspace_path
            config.workspace.file_references.map(&:path).each do |project_path|
              path = File.join File.dirname(config.workspace_path), project_path
              report.log_command "xcodebuild -list -project #{path}"
            end
          end

          base_cmd = report_helper.base_xcodebuild_cmd
          # Add more options for the rest of the commands
          base_cmd = "#{base_cmd} -scheme #{config.scheme}"
          base_cmd = "#{base_cmd} -configuration #{config.configuration} -sdk #{config.sdk}"

          # xcodebuild -showBuildSettings
          xcode_settings.log_xcodebuild_showbuildsettings report

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

      def report_helper
        Helper::ReportHelper
      end

      def xcode_settings
        Configuration::XcodeSettings.new
      end
    end
  end
end
