module BranchIOCLI
  module Format
    module ShellFormat
      include Format

      def option(opt)
        o = @configuration.available_options.find { |o| o.name == opt.to_sym }

        cli_opt = opt.to_s.gsub(/_/, '-')

        all_opts = o.aliases || []

        if o.nil? || o.default_value.nil? || o.default_value != true
          all_opts << "--#{cli_opt}"
        else
          all_opts << "--no-#{cli_opt}"
        end

        all_opts.join(" ")
      end

      def all_commands
        Dir[File.expand_path(File.join("..", "..", "command", "**_command.rb"), __FILE__)].map { |p| p.sub(%r{^.*/([a-z0-9_]+)_command.rb$}, '\1') }
      end

      def options_for_command(command)
        @configuration = Object.const_get("BranchIOCLI")
                               .const_get("Configuration")
                               .const_get("#{command.capitalize}Configuration")
        @configuration.available_options.map { |o| option(o.name) }.join(" ")
      end
    end
  end
end
