# frozen_string_literal: true

require 'bcrypt'

require 'dry/monads/result'
require 'dry/matcher/result_matcher'
require 'hanami/utils/kernel'

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
      @current_user = :unassigned
    end

    def call(token, new_password, current_user: nil)
      init_ivars(current_user)
      verify_no_current_user(token)
      user = verify_token(token)
      Success(user: update(user, new_password))
    rescue LogicError => error
      report_failure(error)
    end

    private

    attr_reader :current_user

    def encrypted(password)
      BCrypt::Password.create(password)
    end

    def expired_token?(entity)
      prea = entity.password_reset_expires_at
      # Calling this on a non-reset Entity is treated as expiring at the epoch
      Time.now > Hanami::Utils::Kernel.Time(prea.to_i)
    end

    # Reek sees a :reek:ControlParameter. Yep.
    def init_ivars(current_user)
      @current_user = current_user || CryptIdent.config.guest_user
    end

    def new_attribs(password)
      { password_hash: encrypted(password), password_reset_expires_at: nil,
        token: nil }
    end

    def raise_logic_error(code, token)
      payload = { code: code, token: token }
      raise LogicError, Marshal.dump(payload)
    end

    def report_failure(error)
      # rubocop:disable Security/MarshalLoad
      error_data = Marshal.load(error.message)
      # rubocop:enable Security/MarshalLoad
      Failure(error_data)
    end

    def update(user, password)
      CryptIdent.config.repository.update(user.id, new_attribs(password))
    end

    def validate_match_and_token(match, token)
      raise_logic_error(:token_not_found, token) unless match
      raise_logic_error(:expired_token, token) if expired_token?(match)
      match
    end

    def verify_no_current_user(token)
      return if !current_user || current_user.guest?

      payload = { code: :invalid_current_user, token: token }
      raise LogicError, Marshal.dump(payload)
    end

    def verify_token(token)
      match = Array(CryptIdent.config.repository.find_by_token(token)).first
      validate_match_and_token(match, token)
    end
  end
end
