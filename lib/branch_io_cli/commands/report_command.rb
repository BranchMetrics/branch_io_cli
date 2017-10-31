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
        cmd = "#{cmd} -project #{config_helper.xcodeproj_path}" if config_helper.xcodeproj_path
        cmd = "#{cmd} -target #{config_helper.target}" if config_helper.target
        cmd = "#{cmd} -configuration #{config_helper.configuration}" if config_helper.configuration
        cmd
      end

      def branch_version
        if config_helper.podfile_path && File.exist?("#{config_helper.podfile_path}.lock")
          podfile_lock = File.read "#{config_helper.podfile_path}.lock"
          matches = %r{Branch/Core \(= (\d+\.\d+\.\d+)\)}m.match podfile_lock
          return matches[1] if matches
        elsif config_helper.cartfile_path && File.exist?("#{config_helper.cartfile_path}.resolved")
          cartfile_resolved = File.read "#{config_helper.cartfile_path}.resolved"
          matches = /ios-branch-deep-linking" "(\d+\.\d+\.\d+)"/m.match cartfile_resolved
          return matches[1] if matches
        end
        nil
      end

      def report_header
        header = `xcodebuild -version`
        version = branch_version
        header = "#{header}\nBranch SDK v. #{version}" if version
        "#{header}\n"
      end
    end
  end
end