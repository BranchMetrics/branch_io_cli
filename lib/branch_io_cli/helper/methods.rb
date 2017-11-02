module BranchIOCLI
  module Helper
    module Methods
      def sh(command, output = STDOUT)
        output.report_command command
      end
    end
  end
end
