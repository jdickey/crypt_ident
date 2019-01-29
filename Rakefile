# frozen_string_literal: true

require 'rake'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'flay'
require 'flay_task'
require 'flog'
require 'flog_task'
require 'inch/rake'
require 'reek/rake/task'
require 'rubocop/rake_task'
require 'fileutils'

Dir.glob('lib/tasks/*.rake').each { |r| load r }

class FlogTask < Rake::TaskLib
  attr_accessor :methods_only
end

desc 'Run unit tests using Entities and a dummied Repository'
task :test do
  Rake::TestTask.new do |t|
    # t.pattern = 'test/**/*_test.rb'
    t.pattern = ['test/crypt_ident_test.rb', 'test/crypt_ident/**/*_test.rb']
    t.libs    << 'test'
    t.warning = false
  end
end

namespace :test do
  desc 'Run integration tests using an actual Hanami Repository and Entity'
  Rake::TestTask.new(:integration) do |t|
    t.pattern = 'test/integration/**/*_test.rb'
    t.libs << 'test'
    t.warning = false
  end
end

FlayTask.new do |t|
  t.verbose = true
  t.dirs = %w(lib)
end

FlogTask.new do |t|
  t.verbose = true
  t.threshold = 400 # default is 200
  t.methods_only = true
  t.dirs = %w(lib) # Look, Ma; no tests! Run the tool manually every so often for those.
end

Inch::Rake::Suggest.new do |suggest|
  # suggest.args = '--pedantic'
end

Reek::Rake::Task.new do |t|
  t.config_file = 'config.reek'
  t.source_files = '{apps,db,lib}/**/*.rb'
  t.reek_opts = '--sort-by smelliness --no-progress  -s'
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = [
    'apps/**/*.rb',
    'db/**/*.rb',
    'lib/**/*.rb',
    'spec/**/*.rb'
  ]
  task.formatters = ['simple', 'd']
  task.fail_on_error = true
  # task.options << '--rails'
  task.options << '--config=.rubocop.yml'
  task.options << '--display-cop-names'
end

namespace :minitest do
  desc 'Reset mean-time reporter stats by removing previous-runs data file'
  task :reset_statistics do
    # *DO NOT* call `Minitest::Reporters::MeanTimeReporter.reset_statistics!`.
    # Ever. Or at least until it's officially fixed. It writes an empty file to
    # the previous-runs file, which crashes any future run of this reporter.
    # FIXME!
    require 'minitest/reporters/mean_time_reporter'
    mtr = Minitest::Reporters::MeanTimeReporter.new
    prfile = mtr.send :previous_runs_filename
    _unlinked = FileUtils.rm_f prfile
    puts 'The mean time reporter statistics have been reset.'
  end
end

task default: [:test, 'test:integration', :flog, :flay, :reek, :rubocop, :inch]
task spec: :test
