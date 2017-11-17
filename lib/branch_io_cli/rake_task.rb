require "rake"
require "rake/tasklib"
require "branch_io_cli"
require "highline/import"

module BranchIOCLI
  class RakeTask < Rake::TaskLib
    attr_reader :defaults

    def initialize(name = :branch, &b)
      namespace name do
        report_task
        setup_task
        validate_task
      end
    end

    def report_task
      desc "Generate a brief Branch report"
      task :report, %i{paths options} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)

        paths.each do |path|
          Dir.chdir(path) do |p|
            Command::ReportCommand.new(Configuration::ReportConfiguration.wrapper(args[:options] || {})).run!
          end
        end
      end
    end

    def setup_task
      desc "Set a project up with the Branch SDK"
      task :setup, %i{paths options} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)

        paths.each do |path|
          Dir.chdir(path) do |p|
            Command::SetupCommand.new(Configuration::SetupConfiguration.wrapper(args[:options] || {})).run!
          end
        end
      end
    end

    def validate_task
      desc "Validate universal links in one or more projects"
      task :validate, %i{paths options} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)

        paths.each do |path|
          Dir.chdir(path) do |p|
            Command::ValidateCommand.new(Configuration::ValidateConfiguration.wrapper(args[:options] || {})).run!
          end
        end
      end
    end
  end
end
