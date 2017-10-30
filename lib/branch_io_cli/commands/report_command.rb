module BranchIOCLI
  module Commands
    class ReportCommand < Command

      def initialize(options)
        super
        config_helper.validate_report_options options
      end

      def run!
        File.open config_helper.report_path, "w" do |report|
          report.write "Branch.io Xcode build report v #{VERSION}\n\n"
          report.write "#{report_header}\n"

          say "Cleaning"
          clean_cmd = "#{base_xcodebuild_cmd} clean"
          report.write "$ #{clean_cmd}\n\n"
          report.write `#{clean_cmd}` if config_helper.clean

          say "Building"
          build_cmd = "#{base_xcodebuild_cmd} -verbose"
          report.write "$ #{build_cmd}\n\n"
          report.write `#{build_cmd}`

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

      def report_header
        <<EOF
#{`xcodebuild -version`}
EOF
      end
    end
  end
end
