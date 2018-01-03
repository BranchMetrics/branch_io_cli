require "shellwords"
require "tty/spinner"

module BranchIOCLI
  module Command
    class ReportCommand < Command
      def run!
        say "\n"

        task = Helper::Task.new
        task.begin "Loading settings from Xcode."

        # In case running in a non-CLI context (e.g., Rake or Fastlane) be sure
        # to reset Xcode settings each time, since project, target and
        # configurations will change.
        Configuration::XcodeSettings.reset
        if Configuration::XcodeSettings.all_valid?
          task.success "Done."
        else
          task.error "Failed."
          say "Failed to load settings from Xcode. Some information may be missing.\n"
        end

        if config.header_only
          say "\n"
          say env.ruby_header
          say report_helper.report_header
          return 0
        end

        if config.report_path == "stdout"
          write_report STDOUT
        else
          File.open(config.report_path, "w") { |f| write_report f }
          say "Report generated in #{config.report_path}"
        end

        0
      end

      def write_report(report)
        report.write "Branch.io Xcode build report v #{VERSION} #{Time.now}\n\n"
        report.write "#{config.report_configuration}\n"

        if report == STDOUT
          say env.ruby_header
        else
          report.write env.ruby_header(terminal: false, include_load_path: true)
        end

        report.write "#{report_helper.report_header}\n"

        tool_helper.pod_install_if_required report
        tool_helper.carthage_bootstrap_if_required report

        # run xcodebuild -list
        report.sh(*report_helper.base_xcodebuild_cmd, "-list")

        # If using a workspace, -list all the projects as well
        if config.workspace_path
          config.workspace.file_references.map(&:path).each do |project_path|
            path = File.join File.dirname(config.workspace_path), project_path
            report.sh "xcodebuild", "-list", "-project", path
          end
        end

        # xcodebuild -showBuildSettings
        config.configurations.each do |configuration|
          Configuration::XcodeSettings[configuration].log_xcodebuild_showbuildsettings report
        end

        base_cmd = report_helper.base_xcodebuild_cmd
        # Add more options for the rest of the commands
        base_cmd += [
          "-scheme",
          config.scheme,
          "-configuration",
          config.configuration || config.configurations_from_scheme.first,
          "-sdk",
          config.sdk
        ]

        if config.clean
          task = Helper::Task.new use_spinner: report != STDOUT
          task.begin "Cleaning."
          if report.sh(*base_cmd, "clean").success?
            task.success "Done."
          else
            task.error "Clean failed."
          end
        end

        task = Helper::Task.new use_spinner: report != STDOUT
        task.begin "Building."
        if report.sh(*base_cmd, "-verbose").success?
          task.success "Done."
        else
          task.error "Failed."
        end
      end

      def report_helper
        Helper::ReportHelper
      end

      def tool_helper
        Helper::ToolHelper
      end
    end
  end
end
