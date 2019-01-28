# frozen_string_literal: true

require 'hanami/model'
require 'securerandom'

class User < Hanami::Entity
  GUEST_EMAIL = 'guest@example.com'
  GUEST_NAME = 'Guest User'
  GUEST_PROFILE = 'This is the Guest User. It can do nothing.'

  def guest?
    name == GUEST_NAME && email == GUEST_EMAIL && profile == GUEST_PROFILE
  end
end

class UserRepository < Hanami::Repository
  def find_by_token(token)
    users.where(token: token).map_to(User).one
  end

  def guest_user
    @guest_user ||= User.new name: User::GUEST_NAME, email: User::GUEST_EMAIL,
                             password_hash: SecureRandom.alphanumeric(48),
                             profile: User::GUEST_PROFILE
  end
end
