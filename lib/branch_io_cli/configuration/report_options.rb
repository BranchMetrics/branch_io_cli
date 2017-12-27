module BranchIOCLI
  module Configuration
    class ReportOptions
      class << self
        def available_options
          [
            Option.new(
              name: :workspace,
              description: "Path to an Xcode workspace",
              type: String,
              example: "MyProject.xcworkspace"
            ),
            Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project",
              type: String,
              example: "MyProject.xcodeproj"
            ),
            Option.new(
              name: :scheme,
              description: "A scheme from the project or workspace to build",
              type: String,
              example: "MyProjectScheme"
            ),
            Option.new(
              name: :target,
              description: "A target to build",
              type: String,
              example: "MyProjectTarget"
            ),
            Option.new(
              name: :configuration,
              description: "The build configuration to use (default: Scheme-dependent)",
              type: String,
              example: "Debug/Release/CustomConfigName"
            ),
            Option.new(
              name: :sdk,
              description: "Passed as -sdk to xcodebuild",
              type: String,
              example: "iphoneos",
              default_value: "iphonesimulator"
            ),
            Option.new(
              name: :podfile,
              description: "Path to the Podfile for the project",
              type: String,
              example: "/path/to/Podfile"
            ),
            Option.new(
              name: :cartfile,
              description: "Path to the Cartfile for the project",
              type: String,
              example: "/path/to/Cartfile"
            ),
            Option.new(
              name: :clean,
              description: "Clean before attempting to build",
              default_value: true
            ),
            Option.new(
              name: :header_only,
              description: "Write a report header to standard output and exit",
              default_value: false,
              aliases: "-H"
            ),
            Option.new(
              name: :pod_repo_update,
              description: "Update the local podspec repo before installing",
              default_value: true
            ),
            Option.new(
              name: :out,
              description: "Report output path",
              default_value: "./report.txt",
              aliases: "-o",
              example: "./report.txt",
              type: String,
              env_name: "BRANCH_REPORT_PATH"
            )
          ] + Option.global_options
        end
      end
    end
  end
end
