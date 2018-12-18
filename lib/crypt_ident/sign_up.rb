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

    def initialize(repo = nil)
      @ci_config = config_with_repo(repo)
    end

    def call(attribs, current_user:)
      return failure_for(:current_user_exists) if current_user?(current_user)

      create_result(all_attribs(attribs))
    end

    private

    attr_reader :ci_config

    def all_attribs(attribs)
      new_attribs.merge(attribs)
    end

    def config_with_repo(repo)
      CryptIdent.configure_crypt_ident do |config|
        config.repository = repo if repo
      end
    end

    # XXX: This has a Flog score of 9.8. Truly simplifying PRs welcome.
    def create_result(attribs_in)
      user = ci_config.repository.create(attribs_in)
      Success(user: user, config: ci_config)
    rescue Hanami::Model::UniqueConstraintViolationError
      failure_for(:user_already_created)
    rescue Hanami::Model::Error
      failure_for(:user_creation_failed)
    end

    def current_user?(user)
      user && !user.guest_user?
    end

    def failure_for(code)
      Failure(code: code, config: ci_config)
    end

    def hashed_password(password_in)
      password = password_in.to_s.strip
      password = SecureRandom.alphanumeric(64) if password.empty?
      ::BCrypt::Password.create(password)
    end

    def new_attribs
      prea = Time.now + ci_config.reset_expiry
      {
        password_hash: hashed_password(nil),
        password_reset_expires_at: prea,
        token: new_token
      }
    end

    def new_token
      token_length = ci_config.token_bytes
      clear_text_token = SecureRandom.alphanumeric(token_length)
      Base64.strict_encode64(clear_text_token)
    end
  end
end
