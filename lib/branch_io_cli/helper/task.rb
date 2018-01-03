require "tty/spinner"

module BranchIOCLI
  module Helper
    class Task
      def initialize(use_spinner: true)
        @use_spinner = use_spinner
      end

      def use_spinner?
        @use_spinner
      end

      def begin(message)
        if use_spinner?
          @spinner = TTY::Spinner.new "[:spinner] #{message}", format: :flip
          @spinner.auto_spin
        end
      end

      def success(message)
        if use_spinner?
          @spinner.success message
        end
      end

      def error(message)
        if use_spinner?
          @spinner.error message
        end
      end
    end
  end
end
