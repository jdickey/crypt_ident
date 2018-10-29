# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'simplecov'
require 'pry-byebug'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::MeanTimeReporter.new
# or ::DefaultReporter or ::HtmlReporter

SimpleCov.start do
  coverage_dir './tmp/coverage'
  add_filter '/lib/tasks/'
  add_filter '/tmp/gemset/'
  # self.formatters = SimpleCov::Formatter::HTMLFormatter
end

require 'crypt_ident'
