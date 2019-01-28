# frozen_string_literal: true

ENV['SQLITE_PATH'] ||= 'sqlite://tmp/dummy_data.sqlite'

require 'fileutils'
require 'hanami/model/sql'
require 'hanami/model/migrator'
require 'hanami/model/migration'

FileUtils.touch './tmp/dummy_data.sqlite'

module DatabaseHelper
  MAPPING = {
    'postgres' => 'POSTGRES_URL',
    'mysql' => 'MYSQL_URL',
    'sqlite' => 'SQLITE_PATH',
  }

  module_function

  def adapter
    ENV['DB'] || 'sqlite'
  end

  def postgres?
    adapter == 'postgres'
  end

  def db_url(desired_adapter = nil)
    env_name = MAPPING.fetch(desired_adapter || adapter)
    ENV[env_name]
  end
end

Hanami::Model.configure do
  adapter :sql, DatabaseHelper.db_url
  logger 'tmp/database.log', level: :trace
  migrations Pathname.new('test/integration/fixtures/migrations').to_s
end
Hanami::Model::Migrator.migrate
Hanami::Model.load!
