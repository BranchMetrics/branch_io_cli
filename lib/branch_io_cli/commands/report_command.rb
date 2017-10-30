module BranchIOCLI
  module Commands
    class ReportCommand < Command

      def initialize(options)
        super
        config_helper.validate_report_options options
      end

      def run!
      end
    end
  end
end
