require 'rake'
require 'rake/clean'
require 'rspec/core/rake_task'
require 'yard'

CLEAN.include %w[coverage doc]

RSpec::Core::RakeTask.new(:spec)


YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

task default: :spec
