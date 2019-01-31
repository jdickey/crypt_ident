# frozen_string_literal: true

require 'hanami/utils/class_attribute'

require_relative './fake_repository'

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
end

class UserRepository < Repository
  include Hanami::Utils::ClassAttribute

  @entity_name = 'User'
  @relation = :user

  def self.guest_user
    profile_text = 'This is the Guest User. It can do nothing.'
    Hanami::Utils::Class.load(entity_name).new id: -1, name: 'Guest User',
                                               profile: profile_text,
                                               email: 'guest@example.com'
  end

  def guest_user
    self.class.guest_user
  end

  def find_by_name(name)
    select(:name, name).first # Issue #26
  end

  def find_by_token(token)
    select(:token, token).first# Issue #26
  end

  # This is here, not because `#create` needs to be implemented in our "real"
  # repository (which subclasses `Hanami::Repository`), but because the fake
  # `Repository` class has no underlying data-persistence layer (and our usual
  # "real" persistence layer is going to be PostreSQL, not Sqlite).
  def create(data)
    unless find_by_name(data.to_h[:name]).nil?
      message = 'PG::UniqueViolation: ERROR:  ' \
        'duplicate key value violates unique constraint "users_name_key"' \
        "\nDETAIL: Key(name)=(#{data.to_h[:name]}) already exists."
      raise Hanami::Model::UniqueConstraintViolationError, message
    end
    super
  end
end
