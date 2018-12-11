# frozen_string_literal: true

require 'bcrypt'

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

require_relative './config'

# Include and interact with `CryptIdent` to add authentication to a
# Hanami controller action.
#
# Note the emphasis on *controller action*; this module interacts with session
# data, which is quite theoretically possible in an Interactor but practically
# *quite* the PITA. YHBW.
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Reset Password using previously-sent Reset Token for non-Authenticated User
  #
  # This class *is not* part of the published API.
  # @private
  class ResetPassword
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    LogicError = Class.new(RuntimeError)

    def initialize
      @current_user = @config = @new_password = @token = :unassigned
    end

    def call(token, new_password, repo: nil, current_user: nil)
      init_ivars(new_password, repo, current_user)
      user = verify_token(token)
      Success(user: update(user, new_password))
    rescue LogicError => error
      report_failure(error)
    end

    private

    attr_reader :config

    def encrypted(password)
      BCrypt::Password.create(password)
    end

    # Reek sees a :reek:ControlParameter for `current_user`. Too bad.
    def init_ivars(new_password, repo, current_user)
      @config = CryptIdent.configure_crypt_ident do |config|
        config.repository = repo if repo
      end
      @current_user = current_user || @config.guest_user
      @new_password = new_password
    end

    def new_attribs(password)
      { password_hash: encrypted(password), password_reset_expires_at: nil,
        token: nil }
    end

    def raise_logic_error(code, token)
      payload = { code: code, config: config, token: token }
      raise LogicError, Marshal.dump(payload)
    end

    def repo
      @config.repository
    end

    def report_failure(error)
      # rubocop:disable Security/MarshalLoad
      error_data = Marshal.load(error.message)
      # rubocop:enable Security/MarshalLoad
      Failure(error_data)
    end

    def update(user, password)
      repo.update(user.id, new_attribs(password))
    end

    def validate_match_and_token(match, token)
      raise_logic_error(:token_not_found, token) unless match
      raise_logic_error(:expired_token, token) if match.expired?
      match
    end

    def verify_token(token)
      match = config.repository.find_by_token(token).first
      validate_match_and_token(match, token)
    end
  end
end
