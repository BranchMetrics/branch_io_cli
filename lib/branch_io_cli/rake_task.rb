require "rake"
require "rake/tasklib"
require "branch_io_cli"
require "highline/import"

module BranchIOCLI
  class RakeTask < Rake::TaskLib
    attr_reader :defaults

    def initialize(name = :branch, &b)
      namespace name do
        add_branch_task :report, "Generate a brief Branch report"
        add_branch_task :setup, "Set a project up with the Branch SDK"
        add_branch_task :validate, "Validate Universal Links in one or more projects"
      end
    end

    def add_branch_task(task_name, description)
      command_class = Command.const_get("#{task_name.to_s.capitalize}Command")
      configuration_class = Configuration.const_get("#{task_name.to_s.capitalize}Configuration")

      desc description
      task task_name, %i{paths options} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)
        options = args[:options] || {}

        paths.each do |path|
          Dir.chdir(path) do
            begin
              command_class.new(configuration_class.wrapper(options)).run!
            rescue StandardError => e
              say "Error from #{task_name} task in #{path}: #{e.message}"
              say e.backtrace if options[:trace]
            end
          end
        end
      end
    end
  end
end
