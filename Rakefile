require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

require 'branch_io_cli/rake_task'
BranchIOCLI::RakeTask.new

task default: [:spec, :rubocop]

ALL_PROJECTS = Dir[File.expand_path("../examples/*Example*", __FILE__)]
desc "Report on all examples in repo"
task :report do
  Rake::Task["branch:report"].invoke ALL_PROJECTS, true, true
end

desc "Perform a full build of all examples in the repo"
task "report:full" do
  Rake::Task["branch:report"].invoke ALL_PROJECTS, true, false, "./report.txt", false
end
