require "rake"
require "rake/tasklib"
require "branch_io_cli"
require "branch_io_cli/helper/methods"
require "highline/import"

module BranchIOCLI
  class RakeTask < Rake::TaskLib
    def initialize(*args, &b)
      namespace :branch do
        report_task
      end
    end

    def report_task
      desc "Generate a brief Branch report"
      task :report, %i{paths} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)

        paths.each do |path|
          Dir.chdir(path) do
            STDOUT.log_command "branch_io report -H -t"
          end
        end
      end
    end
  end
end
