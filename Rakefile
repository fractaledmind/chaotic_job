# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rspec/core/rake_task"
require "standard/rake"

Minitest::TestTask.create :test do |t|
  t.framework = nil
end

RSpec::Core::RakeTask.new(:spec)

desc "Run both Minitest and RSpec test suites with combined coverage"
task :test_all do
  sh "bundle exec rake spec"
  sh "bundle exec rake test"
end

task default: %i[test_all standard]
