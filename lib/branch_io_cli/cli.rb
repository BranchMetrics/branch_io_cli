require "rubygems"
require "commander"

module BranchIOCLI
  class CLI
    include Commander::Methods

    def run
      program :name, "Branch.io command-line interface"
      program :version, VERSION
      program :description, "More to come"

      command :setup do |c|
        c.syntax = "branch_io setup [OPTIONS]"
        c.description = <<EOF
Integrates the Branch SDK into a native app project. This currently supports iOS only.
It will infer the project location if there is exactly one .xcodeproj anywhere under
the current directory, excluding any in a Pods or Carthage folder. Otherwise, specify
the project location using the <%= color('--xcodeproj', BOLD) %> option.

If a Podfile or Cartfile is detected, the Branch SDK will be added to the relevant
configuration file and the dependencies updated to include the Branch framework.
This behavior may be suppressed using <%= color('--no_add_sdk', BOLD) %>. If no Podfile or Cartfile
is found, the SDK dependency must be added manually. This will improve in a future
release.

By default, all supplied Universal Link domains are validated. If validation passes,
the setup continues. If validation fails, no further action is taken. Suppress
validation using <%= color('--no_validate', BOLD) %> or force changes when validation fails using
<%= color('--force', BOLD) %>.

All relevant project settings are modified. The Branch keys are added to the Info.plist,
along with the <%= color('branch_universal_link_domains', BOLD) %> key for custom domains (when <%= color('--domains', BOLD) %>
is used). All domains are added to the project's Associated Domains entitlements.
An entitlements file is added if none is found. Optionally, if <%= color('--frameworks', BOLD) %> is
specified, this command can add a list of system frameworks to the project (e.g.,
AdSupport, CoreSpotlight, SafariServices).

A language-specific patch is applied to the AppDelegate (Swift or Objective-C).
This can be suppressed using <%= color('--no_patch_source', BOLD) %>.

<%= color('Prerequisites', BOLD) %>

Before using this command, make sure to set up your app in the Branch Dashboard
(https://dashboard.branch.io). See https://docs.branch.io/pages/dashboard/integrate/
for details. To use the <%= color('setup', BOLD) %> command, you need:

- Branch key(s), either live, test or both
- Domain name(s) used for Branch links
- Location of your Xcode project (may be inferred in simple projects)

To use the <%= color('--commit', BOLD) %> option, you must have the <%= color('git', BOLD) %> command available in your path.

To add the SDK with CocoaPods or Carthage, you must have the <%= color('pod', BOLD) %> or <%= color('carthage', BOLD) %>
command, respectively, available in your path.

See https://github.com/BranchMetrics/branch_io_cli for more information.
EOF

        # Required Branch params
        c.option "--live_key key_live_xxxx", String, "Branch live key"
        c.option "--test_key key_test_yyyy", String, "Branch test key"
        c.option "--app_link_subdomain myapp", String, "Branch app.link subdomain, e.g. myapp for myapp.app.link"
        c.option "--domains example.com,www.example.com", Array, "Comma-separated list of custom domain(s) or non-Branch domain(s)"

        c.option "--xcodeproj MyProject.xcodeproj", String, "Path to an Xcode project to update"
        c.option "--target MyAppTarget", String, "Name of a target to modify in the Xcode project"
        c.option "--podfile /path/to/Podfile", String, "Path to the Podfile for the project"
        c.option "--cartfile /path/to/Cartfile", String, "Path to the Cartfile for the project"
        c.option "--frameworks AdSupport,CoreSpotlight,SafariServices", Array, "Comma-separated list of system frameworks to add to the project"

        c.option "--no_pod_repo_update", TrueClass, "Skip update of the local podspec repo before installing"
        c.option "--no_validate", TrueClass, "Skip validation of Universal Link configuration"
        c.option "--force", TrueClass, "Update project even if Universal Link validation fails"
        c.option "--no_add_sdk", TrueClass, "Don't add the Branch framework to the project"
        c.option "--no_patch_source", TrueClass, "Don't add Branch SDK calls to the AppDelegate"
        c.option "--commit", TrueClass, "Commit the results to Git"

        c.action do |args, options|
          Command.setup options
        end
      end

      command :validate do |c|
        c.syntax = "branch_io validate [OPTIONS]"
        c.description = "Validate the Universal Link configuration for an Xcode project."

        c.option "--xcodeproj MyProject.xcodeproj", String, "Path to an Xcode project to update"
        c.option "--target MyAppTarget", String, "Name of a target to modify in the Xcode project"
        c.option "--domains example.com,www.example.com", Array, "Comma-separated list of domains to validate (Branch domains or non-Branch domains)"

        c.action do |args, options|
          valid = Command.validate options
          exit_code = valid ? 0 : 1
          exit exit_code
        end
      end

      run!
    end
  end
end
