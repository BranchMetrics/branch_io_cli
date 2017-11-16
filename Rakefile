require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

require 'branch_io_cli/rake_task'
require 'branch_io_cli/format'
BranchIOCLI::RakeTask.new

require 'pattern_patch'

task default: [:spec, :rubocop]

#
# Example tasks
#

IOS_REPO_DIR = File.expand_path "../../ios-branch-deep-linking", __FILE__

def all_projects
  projects = Dir[File.expand_path("../examples/*Example*", __FILE__)]
  if Dir.exist? IOS_REPO_DIR
    projects += Dir[File.expand_path("{Branch-TestBed*,Examples/*}", IOS_REPO_DIR)].reject { |p| p =~ /Xcode-7|README/ }
  end
  projects
end

desc "Set up all repo examples"
task :setup do
  projects = Dir[File.expand_path("../examples/*Example*", __FILE__)]
  Rake::Task["branch:setup"].invoke(
    projects,
    live_key: "key_live_xxxx",
    test_key: "key_test_yyyy",
    domains: %w(myapp.app.link),
    validate: false,
    pod_repo_update: false,
    setting: true
  )
end

desc "Validate repo examples"
task :validate do
  projects = Dir[File.expand_path("../examples/*Example*", __FILE__)]
  Rake::Task["branch:validate"].invoke projects
end

desc "Report on all examples in repo"
task :report do
  Rake::Task["branch:report"].invoke all_projects, header_only: true
end

desc "Perform a full build of all examples in the repo"
task "report:full" do
  Rake::Task["branch:report"].invoke all_projects, pod_repo_update: false
end

#
# Repo maintenance
#

desc "Generate markdown documentation"
task "readme" do
  include BranchIOCLI::Format::MarkdownFormat

  text = "\\1\n"
  text += %i(setup validate report).inject("") do |t, command|
    t + render_command(command)
  end
  text += "\n\\2"

  PatternPatch::Patch.new(
    regexp: /(\<!-- BEGIN COMMAND REFERENCE --\>).*(\<!-- END COMMAND REFERENCE --\>)/m,
    text: text,
    mode: :replace
  ).apply File.expand_path("../README.md", __FILE__)
end
