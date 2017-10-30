module BranchIOCLI
  module Commands
    class ReportCommand < Command

      def initialize(options)
        super
        config_helper.validate_report_options options
      end

      def run!
        system "#{base_xcodebuild_cmd} clean" if config_helper.clean
        system "#{base_xcodebuild_cmd}"
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
