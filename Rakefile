# frozen_string_literal: true

require 'bundler'
require 'bundler/gem_tasks'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end
require 'rake'
require 'rake/clean'
require 'rubocop/rake_task'
require 'rspec/core/rake_task'
require 'yard'

# For code coverage measurements to work properly, `SimpleCov` should be loaded
# and started before any application code is loaded.
task :coverage do
  ENV['COVERAGE'] = 'yes'
  Rake::Task[:spec].invoke
end

CLEAN.include %w[coverage doc *.gem .yardoc]

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task lint: :rubocop

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

task default: :spec
