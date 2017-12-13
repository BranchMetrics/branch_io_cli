module BranchIOCLI
  module Configuration
    class SetupOptions
      class << self
        def available_options
          [
            Option.new(
              name: :live_key,
              description: "Branch live key",
              example: "key_live_xxxx",
              type: String,
              aliases: "-L"
            ),
            Option.new(
              name: :test_key,
              description: "Branch test key",
              example: "key_test_yyyy",
              type: String,
              aliases: "-T"
            ),
            Option.new(
              name: :domains,
              description: "Comma-separated list of custom domain(s) or non-Branch domain(s)",
              example: "example.com,www.example.com",
              type: Array,
              aliases: "-D",
              confirm_symbol: :all_domains
            ),
            Option.new(
              name: :app_link_subdomain,
              description: "Branch app.link subdomain, e.g. myapp for myapp.app.link",
              example: "myapp",
              type: String,
              label: "app.link subdomain",
              skip_confirmation: true
            ),
            Option.new(
              name: :uri_scheme,
              description: "Custom URI scheme used in the Branch Dashboard for this app",
              example: "myurischeme[://]",
              type: String,
              aliases: "-U",
              label: "URI scheme"
            ),
            Option.new(
              name: :setting,
              description: "Use a custom build setting for the Branch key (default: Use Info.plist)",
              example: "BRANCH_KEY_SETTING",
              type: String,
              argument_optional: true,
              aliases: "-s",
              label: "User-defined setting for Branch key"
            ),
            Option.new(
              name: :test_configurations,
              description: "List of configurations that use the test key with a user-defined setting (default: Debug configurations)",
              example: "config1,config2",
              type: Array,
              negatable: true,
              valid_values_proc: -> { Configuration.current.xcodeproj.build_configurations.map(&:name) }
            ),
            Option.new(
              name: :xcodeproj,
              description: "Path to an Xcode project to update",
              example: "MyProject.xcodeproj",
              type: String,
              confirm_symbol: :xcodeproj_path,
              validate_proc: ->(path) { Configuration.open_xcodeproj path }
            ),
            Option.new(
              name: :target,
              description: "Name of a target to modify in the Xcode project",
              example: "MyAppTarget",
              type: String,
              confirm_symbol: :target_name,
              valid_values_proc: -> { Configuration.current.xcodeproj.targets.map(&:name) }
            ),
            Option.new(
              name: :podfile,
              description: "Path to the Podfile for the project",
              example: "/path/to/Podfile",
              type: String,
              confirm_symbol: :podfile_path,
              validate_proc: ->(path) { Configuration.open_podfile path }
            ),
            Option.new(
              name: :cartfile,
              description: "Path to the Cartfile for the project",
              example: "/path/to/Cartfile",
              type: String,
              confirm_symbol: :cartfile_path,
              validate_proc: ->(path) { !path.nil? && File.exist?(path.to_s) },
              convert_proc: ->(path) { Configuration.absolute_path(path.to_s) unless path.nil? }
            ),
            Option.new(
              name: :carthage_command,
              description: "Command to run when installing from Carthage",
              example: "bootstrap --no-use-binaries",
              type: String,
              default_value: "update --platform ios"
            ),
            Option.new(
              name: :frameworks,
              description: "Comma-separated list of system frameworks to add to the project",
              example: "AdSupport,CoreSpotlight,SafariServices",
              type: Array
            ),
            Option.new(
              name: :pod_repo_update,
              description: "Update the local podspec repo before installing",
              default_value: true
            ),
            Option.new(
              name: :validate,
              description: "Validate Universal Link configuration",
              default_value: true
            ),
            Option.new(
              name: :force,
              description: "Update project even if Universal Link validation fails",
              default_value: false
            ),
            Option.new(
              name: :add_sdk,
              description: "Add the Branch framework to the project",
              default_value: true
            ),
            Option.new(
              name: :patch_source,
              description: "Add Branch SDK calls to the AppDelegate",
              default_value: true
            ),
            Option.new(
              name: :commit,
              description: "Commit the results to Git if non-blank",
              type: String,
              example: "message",
              argument_optional: true,
              label: "Commit message"
            ),
            Option.new(
              name: :confirm,
              description: "Confirm configuration before proceeding",
              default_value: true,
              skip_confirmation: true
            )
          ]
        end
      end
    end
  end
end
