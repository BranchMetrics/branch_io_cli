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

desc "Run setup, validate, report and report:full in order"
task all: [:setup, :validate, :report, :"report:full"]

IOS_REPO_DIR = File.expand_path "../../ios-branch-deep-linking", __FILE__
LIVE_KEY = "key_live_fgvRfyHxLBuCjUuJAKEZNdeiAueoTL6R"
TEST_KEY = "key_test_efBNprLtMrryfNERzPVh2gkhxyliNN14"

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
    live_key: LIVE_KEY,
    test_key: TEST_KEY,
    domains: %w(k272.app.link),
    validate: true,
    pod_repo_update: false,
    setting: true,
    confirm: false,
    trace: true
  )
end

desc "Validate repo examples"
task :validate do
  Rake::Task["branch:validate"].invoke(
    all_projects,
    # Expect all projects to have exactly these keys and domains
    live_key: LIVE_KEY,
    test_key: TEST_KEY,
    domains: %w(
      k272.app.link
      k272-alternate.app.link
      k272.test-app.link
      k272-alternate.test-app.link
    ),
    trace: true
  )
end

desc "Report on all examples in repo"
task :report do
  Rake::Task["branch:report"].invoke all_projects, header_only: true, trace: true
end

desc "Perform a full build of all examples in the repo"
task "report:full" do
  Rake::Task["branch:report"].invoke all_projects, pod_repo_update: false, confirm: false, trace: true
end

#
# Repo maintenance
#

desc "Regenerate reference documentation in the repo"
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

  Rake::Task["completions"].invoke
end

desc "Generate completion scripts"
task "completions" do
  require "erb"
  include BranchIOCLI::Format::ShellFormat

  %w(bash zsh).each do |shell|
    template = File.expand_path(File.join("..", "lib", "assets", "templates", "completion.#{shell}.erb"), __FILE__)
    script = File.expand_path(File.join("..", "lib", "assets", "completions", "completion.#{shell}"), __FILE__)
    output = ERB.new(File.read(template)).result binding
    File.write script, output
  end
end
