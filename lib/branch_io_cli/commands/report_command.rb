module BranchIOCLI
  module Commands
    class ReportCommand < Command

      def initialize(options)
        super
        config_helper.validate_report_options options
      end

      def run!
        File.open config_helper.report_path, "w" do |report|
          say "Cleaning"
          report.write `#{base_xcodebuild_cmd} clean` if config_helper.clean
          say "Building"
          report.write `#{base_xcodebuild_cmd}`
          say "Done ✅"
        end
        say "Report generated in #{config_helper.report_path}"
      end

      def base_xcodebuild_cmd
        cmd = "xcodebuild "
        cmd = "#{cmd} -scheme #{config_helper.scheme} " if config_helper.scheme
        cmd = "#{cmd} -workspace #{config_helper.workspace_path} " if config_helper.workspace_path
        cmd = "#{cmd} -project #{config_helper.xcodeproj_path} " if config_helper.xcodeproj_path
        cmd = "#{cmd} -target #{config_helper.target} " if config_helper.target
        cmd = "#{cmd} -configuration #{config_helper.configuration} " if config_helper.configuration
        cmd
      end
    end
  end
end
