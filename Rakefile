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

  namespace :remote_spec do
    desc 'Run RSpec remote tests'
    RSpec::Core::RakeTask.new do |task|
      task.name = 'spec'
      task.pattern = './spec/*/remote/*_spec.rb'
    end

    desc 'Run spec tests'
    task :spec, [:test_name] do |task, args|
      test_name = args[:test_name]
      test_name_arg = "-n \"#{test_name}\"" unless test_name.nil?
      sh_command = "ruby -I\"lib:test\" spec/direct_connect/base_plugin_spec.rb #{test_name_arg}"
      sh sh_command
    end

  end
end


desc 'Force deploy - pass true for windows to fix file permissions'
task :d, [:windows] do |task, args|
  should_fix = args[:windows]
  fix_permissions = 'echo "fixing permissions"; bash -c \'if [[ "`hostname`" = "vagrant" ]]; then chmod 777 -R /vagrant/; fi\''
  delete_folder = "echo 'deleting existing deployment'; rm -rf /vagrant/bundles/plugins/ruby/killbill-direct_connect"
  copy_config = "cp direct_connect.dev.yml /vagrant/bundles/plugins/ruby/killbill-direct_connect/0.0.1/direct_connect.yml"
  sh(fix_permissions) if should_fix
  sh delete_folder
  Rake::Task["build"].invoke
  Rake::Task["killbill:deploy"].invoke(true, "/vagrant/bundles/plugins/ruby")
  sh copy_config
end

# Install tasks to package the plugin for Killbill
require 'killbill/rake_task'
Killbill::PluginHelper.install_tasks

# Run tests by default
task :default => 'test:spec'
