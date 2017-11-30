module BranchIOCLI
  module Helper
    class CommandError < RuntimeError
      attr_reader :status
      def initialize(args)
        message, status = *args
        super message
        @status = status
      end
    end

    module Methods
      # Execute a shell command with reporting.
      # The command itself is logged, then output from
      # both stdout and stderr, then a success or failure
      # message. Raises CommandError on error.
      #
      # If output is STDOUT (the default), no redirection occurs. In all
      # other cases, both stdout and stderr are redirected to output.
      # In these cases, formatting (colors, highlights) may be lost.
      #
      # @param command [String, Array] A shell command to execute
      def sh(command)
        status = STDOUT.log_command command
        raise CommandError, [%{Error executing "#{command}": #{status}.}, status] unless status.success?
      end

      # Clear the screen and move the cursor to the top using highline
      def clear
        say "\e[2J\e[H"
      end

      # Ask a yes/no question with a default
      def confirm(question, default_value)
        yn_opts = default_value ? "Y/n" : "y/N"
        value = ask "#{question} (#{yn_opts}) ", nil

        # Convert to true/false
        dummy_option = Configuration::Option.new({})
        value = dummy_option.convert(value)

        return default_value if value.nil? || value.kind_of?(String)
        value
      end
    end
  end
end
