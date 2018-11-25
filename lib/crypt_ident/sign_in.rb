# frozen_string_literal: true

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

# Reworked sign-in (Authentication) logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Reworked sign-in logic for `CryptIdent`, per Issue #9.
  #
  # This class *is not* part of the published API.
  # @private
  class SignIn
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    # As a reminder, calling `Failure` *does not* interrupt control flow *or*
    # prevent a future `Success` call from overriding the result. This is one
    # case where raising *and catching* an exception is Useful
    def call(user:, password:, current_user: nil)
      set_ivars(user, password, current_user)
      validate_user_and_current_user
      verify_matching_password
      Success(user: user)
    rescue LogicError => error
      Failure(code: error.message.to_sym)
    end

    private

    attr_reader :current_user, :password, :user

    LogicError = Class.new(RuntimeError)
    private_constant :LogicError

    def illegal_current_user?
      !current_user.guest_user? && !same_user?
    end

    def password_comparator
      BCrypt::Password.new(user.password_hash)
    end

    def same_user?
      current_user.name == user.name
    end

    # Reek complains about a :reek:ControlParameter for `current`. Never mind.
    def set_ivars(user, password, current)
      @user = user
      @password = password
      @current_user = current || CryptIdent.configure_crypt_ident.guest_user
    end

    def validate_user_and_current_user
      raise LogicError, 'user_is_guest' if user.guest_user?
      raise LogicError, 'illegal_current_user' if illegal_current_user?
    end

    def verify_matching_password
      match = password_comparator == password
      raise LogicError, 'invalid_password' unless match
    end
  end
end
