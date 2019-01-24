# frozen_string_literal: true

require 'securerandom'

require 'bcrypt'

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

# Reworked sign-up logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Reworked sign-up logic for `CryptIdent`, per Issue #9
  #
  # This class *is not* part of the published API.
  # @private
  class SignUp
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    def call(attribs, current_user:)
      return failure_for(:current_user_exists) if current_user?(current_user)

      create_result(all_attribs(attribs))
    end

    private

    def all_attribs(attribs)
      new_attribs.merge(attribs)
    end

    # XXX: This has a Flog score of 9.8. Truly simplifying PRs welcome.
    def create_result(attribs_in)
      user = CryptIdent.config.repository.create(attribs_in)
      success_for(user)
    rescue Hanami::Model::UniqueConstraintViolationError
      failure_for(:user_already_created)
    rescue Hanami::Model::Error
      failure_for(:user_creation_failed)
    end

    def current_user?(user)
      user && !user.guest?
    end

    def failure_for(code)
      Failure(code: code)
    end

    def hashed_password(password_in)
      password = password_in.to_s.strip
      password = SecureRandom.alphanumeric(64) if password.empty?
      ::BCrypt::Password.create(password)
    end

    def new_attribs
      prea = Time.now + CryptIdent.config.reset_expiry
      {
        password_hash: hashed_password(nil),
        password_reset_expires_at: prea,
        token: new_token
      }
    end

    def new_token
      token_length = CryptIdent.config.token_bytes
      clear_text_token = SecureRandom.alphanumeric(token_length)
      Base64.strict_encode64(clear_text_token)
    end

    def success_for(user)
      Success(user: user)
    end
  end
end
