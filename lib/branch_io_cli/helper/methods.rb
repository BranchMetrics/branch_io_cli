module BranchIOCLI
  module Helper
    class CommandError < RuntimeError
      attr_reader :status
      def initialize(args)
        @args = args.first
        @status = args.second
        super message
      end

      def message
        if @args.count == 1
          return @args.first.shelljoin if @args.first.kind_of?(Array)
          return @args.first.to_s
        else
          return @args.shelljoin
        end
      end
    end

    module Methods
      # Execute a shell command with reporting.
      # The command itself is logged, then output from
      # both stdout and stderr, then a success or failure
      # message. Raises CommandError on error. No redirection occurs.
      #
      # @param command [String, Array] A shell command to execute
      def sh(*command)
        status = STDOUT.sh(*command)
        raise CommandError, [command, status] unless status.success?
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
