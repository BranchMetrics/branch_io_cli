require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

desc "Run RSpec examples and generate a test report"
RSpec::Core::RakeTask.new "spec:report" do |task|
  task.rspec_opts = "--format j --out test_results/report.json"
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

task default: [:spec, :rubocop]

desc "CI task"
task ci: ["spec:report", :rubocop]
