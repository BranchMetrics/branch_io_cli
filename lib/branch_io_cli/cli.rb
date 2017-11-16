require "rubygems"
require "commander"
require "branch_io_cli/format"

module BranchIOCLI
  class CLI
    include Commander::Methods
    include Format::CommanderFormat

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
        c.description = render(:setup_description)

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
