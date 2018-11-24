# frozen_string_literal: true

require 'securerandom'

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
      password_hash = hashed_password(attribs[:password])
      { password_hash: password_hash }.merge(attribs)
    end

    def config_with_repo(repo)
      config_hash = CryptIdent.configure_crypt_ident.to_h
      config_hash[:repository] = repo if repo
      Config.new config_hash
    end

    # XXX: This has a Flog score of 9.8. Truly simplifying PRs welcome.
    def create_result(all_attribs)
      user = ci_config.repository.create(all_attribs)
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
      password = SecureRandom.urlsafe_base64(64) if password.empty?
      ::BCrypt::Password.create(password)
    end
  end
end
