# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  coverage_dir './tmp/coverage'
  add_filter '/lib/tasks/'
  add_filter '/tmp/gemset/'
end

require 'support/minitest_helper'

# require 'hanami/model'
require 'hanami/model/error'
require 'hanami/entity'
require 'hanami/utils/kernel'

require 'support/unit_test_model_and_repo_classes'

require 'crypt_ident'
