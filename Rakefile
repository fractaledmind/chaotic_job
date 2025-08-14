# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create :test do |t|
  t.framework = nil
end

require "standard/rake"

desc "Run RSpec tests"
task :spec do
  sh "bundle exec rspec"
end

desc "Run both Minitest and RSpec test suites with combined coverage"
task :test_all do
  puts "Running RSpec tests..."
  sh "bundle exec rspec"
  puts "\nRunning Minitest tests..."
  sh "bundle exec rake test"
  puts "\nCombined coverage report generated in coverage/"
end

task default: %i[test standard]
