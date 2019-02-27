# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__) # unless const_defined?(SimpleCov)

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/tagz'
require 'hanami/utils/class'
require 'hanami/utils/string'

# reporter_name = ENV['REPORTER'] || 'SpecReporter'
reporter_name = ENV['REPORTER'] || 'DefaultReporter'
reporter_name = 'minitest/reporters/' + reporter_name
reporter_name = Hanami::Utils::String.classify(reporter_name)
Reporter = Hanami::Utils::Class.load(reporter_name)
AllReporterArgs = {
  Minitest::Reporters::DefaultReporter => {
    slow_count: 5,
    slow_suite_count: 3
  },
  Minitest::Reporters::HtmlReporter => { reports_dir: 'tmp/test_reports' }
}
ReporterArgs = AllReporterArgs.fetch(Reporter, {})
Minitest::Reporters.use! Reporter.new(ReporterArgs)

tags = ENV['TAGS'].split(',') if ENV['TAGS']
tags ||= []
tags << 'focus'
Minitest::Tagz.choose_tags(*tags, run_all_if_no_match: true)
