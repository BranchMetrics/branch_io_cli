require "open3"
require "shellwords"

module BranchIOCLI
  module Configuration
    class XcodeSettings
      class << self
        def all_valid?
          Configuration.current.configurations.map { |c| settings(c) }.all?(&:valid?)
        end

        def [](configuration)
          settings configuration
        end

        def settings(configuration = Configuration.current.configurations.first)
          return @settings[configuration] if @settings && @settings[configuration]
          @settings ||= {}

          @settings[configuration] = self.new configuration
        end

        def reset
          @settings = {}
        end
      end

      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
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
        cmd += " -showBuildSettings"
        cmd += " -project #{Shellwords.escape config.xcodeproj_path}"
        cmd += " -target #{Shellwords.escape config.target.name}"
        cmd += " -sdk #{Shellwords.escape config.sdk}"
        cmd += " -configuration #{Shellwords.escape configuration}"
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
        if report == STDOUT
          say "<%= color('$ #{xcodebuild_cmd}', [MAGENTA, BOLD]) %>\n\n"
        else
          report.write "$ #{xcodebuild_cmd}\n\n"
        end

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
