require "rubygems"
require "commander"

module BranchIOCLI
  class CLI
    include Commander::Methods

    def run
      program :name, "Branch.io command-line interface"
      program :version, VERSION
      program :description, <<EOF
Command-line tool to integrate the Branch SDK into mobile app projects (currently
iOS only) and validate Universal Link domains
EOF

      command :setup do |c|
        c.syntax = "branch_io setup [OPTIONS]"
        c.summary = "Integrates the Branch SDK into a native app project"
        c.description = <<EOF
Integrates the Branch SDK into a native app project. This currently supports iOS only.
It will infer the project location if there is exactly one .xcodeproj anywhere under
the current directory, excluding any in a Pods or Carthage folder. Otherwise, specify
the project location using the <%= color('--xcodeproj', BOLD) %> option, or the CLI will prompt you for the
location.

If a Podfile or Cartfile is detected, the Branch SDK will be added to the relevant
configuration file and the dependencies updated to include the Branch framework.
This behavior may be suppressed using <%= color('--no-add-sdk', BOLD) %>. If no Podfile or Cartfile
is found, and Branch.framework is not already among the project's dependencies,
you will be prompted for a number of choices, including setting up CocoaPods or
Carthage for the project or directly installing the Branch.framework.

By default, all supplied Universal Link domains are validated. If validation passes,
the setup continues. If validation fails, no further action is taken. Suppress
validation using <%= color('--no-validate', BOLD) %> or force changes when validation fails using
<%= color('--force', BOLD) %>.

By default, this command will look for the first app target in the project. Test
targets are not supported. To set up an extension target, supply the <%= color('--target', BOLD) %> option.

All relevant target settings are modified. The Branch keys are added to the Info.plist,
along with the <%= color('branch_universal_link_domains', BOLD) %> key for custom domains (when <%= color('--domains', BOLD) %>
is used). For app targets, all domains are added to the project's Associated Domains
entitlement. An entitlements file is also added for app targets if none is found.
Optionally, if <%= color('--frameworks', BOLD) %> is specified, this command can add a list of system
frameworks to the target's dependencies (e.g., AdSupport, CoreSpotlight, SafariServices).

A language-specific patch is applied to the AppDelegate (Swift or Objective-C).
This can be suppressed using <%= color('--no-patch-source', BOLD) %>.

<%= color('Prerequisites', BOLD) %>

Before using this command, make sure to set up your app in the Branch Dashboard
(https://dashboard.branch.io). See https://docs.branch.io/pages/dashboard/integrate/
for details. To use the <%= color('setup', BOLD) %> command, you need:

- Branch key(s), either live, test or both
- Domain name(s) used for Branch links
- Location of your Xcode project (may be inferred in simple projects)

If using the <%= color('--commit', BOLD) %> option, <%= color('git', BOLD) %> is required. If not using <%= color('--no-add-sdk', BOLD) %>,
the <%= color('pod', BOLD) %> or <%= color('carthage', BOLD) %> command may be required. If not found, the CLI will
offer to install and set up these command-line tools for you. Alternately, you can arrange
that the relevant commands are available in your <%= color('PATH', BOLD) %>.

All parameters are optional. A live key or test key, or both is required, as well
as at least one domain. Specify <%= color('--live-key', BOLD) %>, <%= color('--test-key', BOLD) %> or both and <%= color('--app-link-subdomain', BOLD) %>,
<%= color('--domains', BOLD) %> or both. If these are not specified, this command will prompt you
for this information.

See https://github.com/BranchMetrics/branch_io_cli#setup-command for more information.
EOF

        add_options_for_command :setup, c

        c.example "Test without validation (can use dummy keys and domains)", "branch_io setup -L key_live_xxxx -D myapp.app.link --no-validate"
        c.example "Use both live and test keys", "branch_io setup -L key_live_xxxx -T key_test_yyyy -D myapp.app.link"
        c.example "Use custom or non-Branch domains", "branch_io setup -D myapp.app.link,example.com,www.example.com"
        c.example "Avoid pod repo update", "branch_io setup --no-pod-repo-update"
        c.example "Install using carthage bootstrap", "branch_io --carthage-command \"bootstrap --no-use-binaries\""

        c.action do |args, options|
          options.default(
            # Defaults for boolean options
            pod_repo_update: true,
            validate: true,
            force: false,
            add_sdk: true,
            patch_source: true,
            commit: false,
            carthage_command: "update --platform ios"
          )
          Command::SetupCommand.new(options).run!
        end
      end

      command :validate do |c|
        c.syntax = "branch_io validate [OPTIONS]"
        c.summary = "Validates all Universal Link domains configured in a project"
        c.description = <<EOF
This command validates all Universal Link domains configured in a project without making any
modification. It validates both Branch and non-Branch domains. Unlike web-based Universal
Link validators, this command operates directly on the project. It finds the bundle and
signing team identifiers in the project as well as the app's Associated Domains. It requests
the apple-app-site-association file for each domain and validates the file against the
project's settings.

Only app targets are supported for this command. By default, it will validate the first.
If your project has multiple app targets, specify the <%= color('--target', BOLD) %> option to validate other
targets.

All parameters are optional. If <%= color('--domains', BOLD) %> is specified, the list of Universal Link domains in
the Associated Domains entitlement must exactly match this list, without regard to order. If
no <%= color('--domains', BOLD) %> are provided, validation passes if at least one Universal Link domain is
configured and passes validation, and no Universal Link domain is present that does not pass
validation.

See https://github.com/BranchMetrics/branch_io_cli#validate-command for more information.
EOF

        add_options_for_command :validate, c

        c.action do |args, options|
          valid = Command::ValidateCommand.new(options).run!
          exit_code = valid ? 0 : 1
          exit exit_code
        end
      end

      command :report do |c|
        c.syntax = "branch_io report [OPTIONS]"
        c.summary = "Generate and optionally submit a build diagnostic report."
        c.description = <<EOF
<%= color('Work in progress', BOLD) %>

This command optionally cleans and then builds a workspace or project, generating a verbose
report with additional diagnostic information suitable for opening a support ticket.
EOF

        add_options_for_command :report, c

        c.action do |args, options|
          defaults = available_options.reject { |o| o.default_value.nil? }.inject({}) do |defs, o|
            defs.merge o.name => o.default_value
          end
          options.default defaults
          Command::ReportCommand.new(options).run!
        end
      end

      run!
    end

    def add_options_for_command(name, c)
      configuration_class = Object.const_get("BranchIOCLI")
                                  .const_get("Configuration")
                                  .const_get("#{name.to_s.capitalize}Configuration")
      available_options = configuration_class.available_options
      available_options.each do |option|
        args = option.aliases
        declaration = "--"
        declaration += "[no-]" if option.negatable
        declaration += "#{option.name.to_s.gsub(/_/, '-')} "
        declaration += "[" if option.argument_optional
        declaration += option.example if option.example
        declaration += "]" if option.argument_optional
        args << declaration
        args << option.type if option.type

        if option.type.nil?
          default_value = option.default_value ? "yes" : "no"
        else
          default_value = option.default_value
        end

        default_string = default_value ? " (default: #{default_value})" : nil
        args << "#{option.description}#{default_string}"
        c.option(*args)
      end
    end
  end
end
