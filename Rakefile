require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

require 'branch_io_cli/rake_task'
BranchIOCLI::RakeTask.new

task default: [:spec, :rubocop]

IOS_REPO_DIR = File.expand_path "../../ios-branch-deep-linking", __FILE__

def all_projects
  projects = Dir[File.expand_path("../examples/*Example*", __FILE__)]
  if Dir.exist? IOS_REPO_DIR
    projects += Dir[File.expand_path("{Branch-TestBed*,Examples/*}", IOS_REPO_DIR)].reject { |p| p =~ /Xcode-7|README/ }
  end
  projects
end

desc "Report on all examples in repo"
task :report do
  Rake::Task["branch:report"].invoke all_projects, header_only: true
end

desc "Perform a full build of all examples in the repo"
task "report:full" do
  Rake::Task["branch:report"].invoke all_projects, pod_repo_update: false
end
