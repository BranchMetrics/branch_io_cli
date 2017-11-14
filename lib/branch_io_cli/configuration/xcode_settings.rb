require "open3"
require "shellwords"

module BranchIOCLI
  module Configuration
    class XcodeSettings
      class << self
        def settings
          return @settings if @settings
          @settings = XcodeSettings.new
          @settings
        end
      end

      def initialize
        load_settings_from_xcode
      end

      def valid?
        @xcodebuild_showbuildsettings_status.success?
      end

      def config
        Configuration.current
      end

      def [](key)
        @xcode_settings[key]
      end

      def xcodebuild_cmd
        cmd = "xcodebuild"
        if config.workspace_path
          cmd = "#{cmd} -workspace #{Shellwords.escape config.workspace_path}"
        else
          cmd = "#{cmd} -project #{Shellwords.escape config.xcodeproj_path}"
        end
        cmd += " -scheme #{Shellwords.escape config.scheme}"
        cmd += " -configuration #{Shellwords.escape config.configuration}"
        cmd += " -sdk #{Shellwords.escape config.sdk}"
        cmd += " -showBuildSettings"
        cmd
      end

      def load_settings_from_xcode
        @xcodebuild_showbuildsettings_output = ""
        @xcode_settings = {}
        Open3.popen2e(xcodebuild_cmd) do |stdin, output, thread|
          while (line = output.gets)
            @xcodebuild_showbuildsettings_output += line
            line.strip!
            next unless (matches = /^(.+)\s+=\s+(.+)$/.match line)
            @xcode_settings[matches[1]] = matches[2]
          end
          @xcodebuild_showbuildsettings_status = thread.value
        end
      end

      def log_xcodebuild_showbuildsettings(report = STDOUT)
        report.write "$ #{xcodebuild_cmd}\n\n"
        report.write @xcodebuild_showbuildsettings_output
        if valid?
          report.write "Success.\n\n"
        else
          report.write "#{@xcodebuild_showbuildsettings_status}.\n\n"
        end
      end
    end
  end
end
