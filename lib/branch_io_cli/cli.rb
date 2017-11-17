require "rubygems"
require "commander"
require "branch_io_cli/format"

module BranchIOCLI
  class CLI
    include Commander::Methods
    include Format::HighlineFormat

    def run
      program :name, "Branch.io command-line interface"
      program :version, VERSION
      program :description, render(:program_description)

      command :setup do |c|
        c.syntax = "branch_io setup [OPTIONS]"
        c.summary = "Integrates the Branch SDK into a native app project"
        c.description = render :setup_description

        add_options_for_command :setup, c

        Command::SetupCommand.examples.each_key do |text|
          example = Command::SetupCommand.examples[text]
          c.example text, example
        end

        c.action do |args, options|
          options.default Configuration::SetupConfiguration.defaults
          Command::SetupCommand.new(options).run!
        end
      end

      command :validate do |c|
        c.syntax = "branch_io validate [OPTIONS]"
        c.summary = "Validates all Universal Link domains configured in a project"
        c.description = render :validate_description

        add_options_for_command :validate, c

        c.action do |args, options|
          options.default Configuration::ValidateConfiguration.defaults
          valid = Command::ValidateCommand.new(options).run!
          exit_code = valid ? 0 : 1
          exit exit_code
        end
      end

      command :report do |c|
        c.syntax = "branch_io report [OPTIONS]"
        c.summary = "Generate and optionally submit a build diagnostic report."
        c.description = render :report_description

        add_options_for_command :report, c

        c.action do |args, options|
          options.default Configuration::ReportConfiguration.defaults
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
        if option.example
          declaration += "[" if option.argument_optional
          declaration += option.example
          declaration += "]" if option.argument_optional
        end
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
