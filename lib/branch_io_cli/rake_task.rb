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
            Command::ReportCommand.new(report_options(args[:options])).run!
          end
        end
      end
    end

    # rubocop: disable Metrics/PerceivedComplexity
    def report_options(options)
      options ||= {}
      defs = defaults[:report]

      if options[:clean].nil? && defs[:clean].nil?
        clean = true
      else
        clean = options[:clean] || defs[:clean]
      end

      if options[:pod_repo_update].nil? && defs[:pod_repo_update].nil?
        repo_update = true
      else
        repo_update = options[:pod_repo_update] || defs[:pod_repo_update]
      end

      if options[:header_only].nil? && defs[:header_only].nil?
        header_only = false
      else
        header_only = options[:header_only] || defs[:header_only]
      end

      ReportOptions.new(
        options[:cartfile] || defs[:cartfile],
        clean,
        options[:configuration] || defs[:configuration],
        header_only,
        options[:out] || defs[:out] || "./report.txt",
        repo_update,
        options[:podfile] || defs[:podfile],
        options[:scheme] || defs[:scheme],
        options[:sdk] || defs[:sdk] || "iphonesimulator",
        options[:target] || defs[:target],
        options[:xcodeproj] || defs[:xcodeproj],
        options[:workspace] || defs[:workspace]
      )
    end
    # rubocop: enable Metrics/PerceivedComplexity
  end
end
