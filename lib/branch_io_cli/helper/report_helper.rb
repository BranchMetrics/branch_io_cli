require "branch_io_cli/configuration/configuration"

module BranchIOCLI
  module Helper
    class ReportHelper
      class << self
        def report_imports
          report = "Branch imports:\n"
          config.branch_imports.each_key do |path|
            report += " #{config.relative_path path}:\n"
            report += "  #{config.branch_imports[path].join("\n  ")}"
            report += "\n"
          end
          report
        end

        def config
          Configuration::Configuration.current
        end
      end
    end
  end
end
