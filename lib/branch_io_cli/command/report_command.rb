require "shellwords"

module BranchIOCLI
  module Command
    class ReportCommand < Command
      def run!
        say "\n"

        say "Loading settings from Xcode"
        if xcode_settings.valid?
          say "Done ✅"
        else
          say "Failed to load settings from Xcode. Some information may be missing.\n"
        end

        if config.header_only
          say report_helper.report_header
          exit 0
        end

        if config.report_path == "stdout"
          write_report STDOUT
        else
          File.open(config.report_path, "w") { |f| write_report f }
          say "Report generated in #{config.report_path}"
        end
      end

      def write_report(report)
        report.write "Branch.io Xcode build report v #{VERSION} #{DateTime.now}\n\n"
        report.write "#{config.report_configuration}\n"
        report.write "#{report_helper.report_header}\n"

        report_helper.pod_install_if_required report

        # run xcodebuild -list
        report.log_command "#{report_helper.base_xcodebuild_cmd} -list"

        # If using a workspace, -list all the projects as well
        if config.workspace_path
          config.workspace.file_references.map(&:path).each do |project_path|
            path = File.join File.dirname(config.workspace_path), project_path
            report.log_command "xcodebuild -list -project #{Shellwords.escape path}"
          end
        end

        # xcodebuild -showBuildSettings
        xcode_settings.log_xcodebuild_showbuildsettings report

        base_cmd = report_helper.base_xcodebuild_cmd
        # Add more options for the rest of the commands
        base_cmd += " -scheme #{Shellwords.escape config.scheme}"
        base_cmd += " -configuration #{Shellwords.escape config.configuration}"
        base_cmd += " -sdk #{Shellwords.escape config.sdk}"

        if config.clean
          say "Cleaning"
          if report.log_command("#{base_cmd} clean").success?
            say "Done ✅"
          else
            say "Clean failed."
          end
        end

        say "Building"
        if report.log_command("#{base_cmd} -verbose").success?
          say "Done ✅"
        else
          say "Build failed."
        end

        say "Done ✅"
      end

      def report_helper
        Helper::ReportHelper
      end

      def xcode_settings
        Configuration::XcodeSettings.settings
      end
    end
  end
end
