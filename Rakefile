#!/usr/bin/env rake

# Install tasks to build and release the plugin
require 'bundler/setup'
Bundler::GemHelper.install_tasks

# Install test tasks
require 'rspec/core/rake_task'
namespace :test do
  desc 'Run RSpec tests'
  RSpec::Core::RakeTask.new do |task|
    task.name = 'spec'
    task.pattern = './spec/*/*_spec.rb'
  end

  desc 'Run Gateway unit tests'
  task :unit, [:test_name] do |task, args|
    test_name = args[:test_name]
    test_name_arg = "-n \"#{test_name}\"" unless test_name.nil?
    sh_command = "ruby -I\"lib:test\" spec/direct_connect/unit/direct_connect_gateway_test.rb #{test_name_arg}"
    sh sh_command
  end

  desc 'Run Gateway remote tests'
  task :remote, [:test_name] do |task, args|
    test_name = args[:test_name]
    test_name_arg = "-n \"#{test_name}\"" unless test_name.nil?
    sh_command = "ruby -I\"lib:test\" spec/direct_connect/remote/remote_direct_connect_gateway_test.rb #{test_name_arg}"
    sh sh_command
  end

  namespace :remote_unused do
    desc 'Run RSpec remote tests'
    RSpec::Core::RakeTask.new do |task|
      task.name = 'spec'
      task.pattern = './spec/*/remote/*_spec.rb'
    end
  end
end

# Install tasks to package the plugin for Killbill
require 'killbill/rake_task'
Killbill::PluginHelper.install_tasks

# Run tests by default
task :default => 'test:spec'
