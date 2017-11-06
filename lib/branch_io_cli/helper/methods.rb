module BranchIOCLI
  module Helper
    class CommandError < RuntimeError; end

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
      # :command: [String] A shell command to execute
      # :output: [IO] An optional IO object to receive stdout and stderr from the command
      def sh(command, output = STDOUT)
        status = output.log_command command
        raise CommandError, %{Error executing "#{command}": #{status}.} unless status.success?
      end
    end
  end
end

include BranchIOCLI::Helper::Methods
