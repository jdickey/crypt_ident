# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'simplecov'
require 'pry-byebug'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/tagz'

tags = ENV['TAGS'].split(',') if ENV['TAGS']
tags ||= []
tags << 'focus'
Minitest::Tagz.choose_tags(*tags, run_all_if_no_match: true)

require 'hanami/model'
require 'hanami/utils/kernel'

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

SimpleCov.start do
  coverage_dir './tmp/coverage'
  add_filter '/lib/tasks/'
  add_filter '/tmp/gemset/'
end

require 'crypt_ident'

require 'hanami/utils/class_attribute'

class User < Hanami::Entity
  attributes do
    attribute :id, Types::Int
    attribute :name, Types::String
    attribute :password_hash, Types::String
    attribute :password_reset_expires_at, Types::Time
    attribute :token, Types::String
    attribute :created_at, Types::Time.default { Time.now }
    attribute :updated_at, Types::Time.default { Time.now }
  end

  def guest?
    @attributes[:id] && @attributes[:id] < 1
  end

  def expired?
    prea = @attributes[:password_reset_expires_at]
    # Calling this on a non-reset Entity is treated as expiring at the epoch
    Time.now > Hanami::Utils::Kernel.Time(prea.to_i)
  end
end

class Repository
  include Hanami::Utils::ClassAttribute

  class_attribute :entity_name, :relation

  def initialize(*_args, **_params)
    @next_id = 1
    @records = {}
  end

  def create(data)
    unless find_by_name(data.to_h[:name]).empty?
      message = 'PG::UniqueViolation: ERROR:  ' \
        'duplicate key value violates unique constraint "users_name_key"' \
        "\nDETAIL: Key(name)=(#{data.to_h[:name]}) already exists."
      raise Hanami::Model::UniqueConstraintViolationError, message
    end
    extra_attribs = { id: @next_id, created_at: Time.now, updated_at: Time.now }
    attribs = extra_attribs.merge(data.to_h)
    record = User.new attribs
    @records[@next_id] = record
    @next_id += 1
    record
  end

  def update(id, data)
    record = find(id)
    return nil unless record
    new_attribs = record.to_h.merge(updated_at: Time.now).merge(data.to_h)
    @records[record.id] = User.new(new_attribs)
  end

  def delete(id)
    @records.delete id
  end

  def all
    @records.values.sort_by(&:id)
  end

  def find(id)
    @records[id]
  end

  def find_by_name(name)
    select(:name, name)
  end

  def find_by_token(token)
    select(:token, token)
  end

  def first
    all.first
  end

  def last
    all.last
  end

  def clear
    @records = {}
  end

  private

  def select(key, value)
    @records.values.select { |other| other.to_h[key] == value }
  end
end

class UserRepository < Repository
  include Hanami::Utils::ClassAttribute

  @entity_name = 'User'
  @relation = :user

  def self.guest_user
    Hanami::Utils::Class.load(entity_name).new id: -1, name: 'Guest User'
  end

  def guest_user
    self.class.guest_user
  end

  def find_by_name(name)
    select(:name, name)
  end

  def find_by_token(token)
    select(:token, token)
  end
end
