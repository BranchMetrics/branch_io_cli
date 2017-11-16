require "rake"
require "rake/tasklib"
require "branch_io_cli"
require "highline/import"

module BranchIOCLI
  class RakeTask < Rake::TaskLib
    ReportOptions = Struct.new(
      :cartfile,
      :clean,
      :configuration,
      :header_only,
      :out,
      :pod_repo_update,
      :podfile,
      :scheme,
      :sdk,
      :target,
      :xcodeproj,
      :workspace
    )

    def initialize(*args, &b)
      namespace :branch do
        report_task
      end
    end

    def report_task
      desc "Generate a brief Branch report"
      task :report, %i{paths clean header_only out pod_repo_update sdk} do |task, args|
        paths = args[:paths]
        paths = [paths] unless paths.respond_to?(:each)
        clean = args[:clean].nil? ? true : args[:clean]
        repo_update = args[:pod_repo_update].nil? ? true : args[:pod_repo_update]

        options = ReportOptions.new(
          nil,
          clean,
          nil,
          args[:header_only],
          args[:out] || "./report.txt",
          repo_update,
          nil,
          nil,
          args[:sdk] || "iphonesimulator",
          nil,
          nil,
          nil
        )

        paths.each do |path|
          Dir.chdir(path) do
            Command::ReportCommand.new(options).run!
          end
        end
      end
    end
  end
end
