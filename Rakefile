#!/usr/bin/env rake
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "tests/test_*.rb"
  t.libs    = %w(libraries)
end

desc "Run tests"
task :default => :test
