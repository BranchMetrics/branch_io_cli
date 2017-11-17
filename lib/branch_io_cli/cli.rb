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

      # Automatically detect all commands from branch_io_cli/command.
      all_commands = Dir[File.expand_path(File.join("..", "command", "*_command.rb"), __FILE__)].map do |path|
        File.basename(path, ".rb").sub(/_command$/, "")
      end

      all_commands.each do |command_name|
        configuration_class = configuration_class command_name
        command_class = command_class command_name
        next unless configuration_class && command_class

        command command_name do |c|
          c.syntax = "branch_io #{c.name} [OPTIONS]"
          c.summary = configuration_class.summary if configuration_class.respond_to?(:summary)

          begin
            c.description = render "#{c.name}_description"
          rescue Errno::ENOENT
          end

          add_options_for_command c

          if configuration_class.respond_to?(:examples) && configuration_class.examples
            configuration_class.examples.each_key do |text|
              example = configuration_class.examples[text]
              c.example text, example
            end
          end

          c.action do |args, options|
            options.default configuration_class.defaults
            return_value = command_class.new(options).run!
            exit(0) unless configuration_class.respond_to?(:return_value_map) &&
                           configuration_class.return_value_map &&
                           configuration_class.return_value_map.respond_to?(:[])

            exit configuration_class.return_value_map[return_value]
          end
        end
      end

      run!
    end

    def configuration_class(name)
      class_for_command name, :configuration
    end

    def command_class(name)
      class_for_command name, :command
    end

    def class_for_command(name, type)
      type_name = type.to_s.capitalize
      type_module = Object.const_get("BranchIOCLI").const_get(type_name)
      candidate = type_module.const_get("#{name.to_s.capitalize}#{type_name}")
      return nil unless candidate

      base = type_module.const_get(type_name)
      return nil unless candidate.superclass == base
      candidate
    end

    def add_options_for_command(c)
      configuration_class = configuration_class(c.name)
      return unless configuration_class.respond_to?(:available_options)

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
