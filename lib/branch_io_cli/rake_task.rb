require "rake"
require "rake/tasklib"
require "branch_io_cli"
require "highline/import"

module BranchIOCLI
  class RakeTask < Rake::TaskLib
    attr_reader :defaults

    def initialize(defaults = {}, &b)
      @defaults = defaults
      @defaults[:report] ||= {}

      namespace :branch do
        report_task
      end
    end

    def report_task
      desc "Generate a brief Branch report"
      task :report, %i{paths options} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)

        paths.each do |path|
          Dir.chdir(path) do |p|
            Command::ReportCommand.new(Configuration::ReportConfiguration.wrapper(args[:options])).run!
          end
        end
      end
    end
  end
end
