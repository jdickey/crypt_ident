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

require 'hanami/controller'
require 'hanami/action'
require 'hanami/action/session'
require 'hanami/model'

reporter_name = ENV['REPORTER'] || 'SpecReporter'
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
    attribute :password_reset_sent_at, Types::Time
    attribute :token, Types::String
    attribute :created_at, Types::Time.default { Time.now }
    attribute :updated_at, Types::Time.default { Time.now }
  end

  def guest_user?
    @attributes[:id] && @attributes[:id] < 1
  end
end

class UserRepository
  include Hanami::Utils::ClassAttribute

  attr_reader :args, :params

  @entity_name = 'User'
  @relation = :user
  class_attribute :entity_name, :relation

  def self.guest_user
    Hanami::Utils::Class.load(entity_name).new id: -1, name: 'Guest User'
  end

  def guest_user
    self.class.guest_user
  end

  def initialize(*args, **params)
    @args = args
    @params = params
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
    @records.values.select { |other| other.name == name }
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
end

class Login
  include Hanami::Action
  include Hanami::Action::Session
  include CryptIdent

  def call(params)
    @user = params.env[:user]
    # begin of TB's test #login
    session[:current_user] = @user
    session[:session_start_time] = Time.now
    flash[:success] = 'You were successfully logged in.'
  end
end # class Login
