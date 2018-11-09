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
require 'hanami/action/session'
require 'hanami/model'

if ENV['HTML_REPORTS']
  Reporter = Minitest::Reporters::HtmlReporter
  ReporterArgs = { reports_dir: 'tmp/test_reports' }
else
  Reporter = Minitest::Reporters::SpecReporter
  ReporterArgs = {}
end
# Reporter = Minitest::Reporters::DefaultReporter
# ReporterArgs = { slow_count: 5, slow_suite_count: 3 }
Minitest::Reporters.use! Reporter.new(ReporterArgs)

SimpleCov.start do
  coverage_dir './tmp/coverage'
  add_filter '/lib/tasks/'
  add_filter '/tmp/gemset/'
  # self.formatters = SimpleCov::Formatter::HTMLFormatter
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
    attribs = { id: next_id }.merge data.to_h
    record = User.new attribs
    @records[next_id] = record
    next_id += 1
    record
  end

  def update(id, data)
    record = find(id)
    return nil unless record
    record = User.new record.to_h
      .merge(updated_at: Time.now)
      .merge(data.to_h)
    @records[record.id] = record
  end

  def delete(id)
    @records.delete id
  end

  def all
    records.values.sort_by(&:id)
  end

  def find(id)
    records[id]
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

  attr_reader :next_id, :records
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
