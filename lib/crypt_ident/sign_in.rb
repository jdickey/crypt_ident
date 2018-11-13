# frozen_string_literal: true

require 'securerandom'

# Sign-in (Authentication) logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Sign-in logic for `CryptIdent`, extracted from original `#sign_in` method.
  #
  # This class *is not* part of the published API.
  # @private
  class SignIn
    def call(user:, password:, current_user: nil)
      set_ivars(user, password, current_user)
      return nil if guard_condition_failed?

      match = password_comparator == password
      match ? user : nil
    end

    private

    attr_reader :current_user, :password, :user

    def current_user_same?
      current_user.name == user.name
    end

    def guard_condition_failed?
      user.guest_user? || illegal_current_user?
    end

    def illegal_current_user?
      !current_user.guest_user? && !current_user_same?
    end

    def password_comparator
      BCrypt::Password.new(user.password_hash)
    end

    # Reek complains about a :reek:ControlParameter for `current`. Never mind.
    def set_ivars(user, password, current)
      @user = user
      @password = password
      @current_user = current || CryptIdent.configure_crypt_ident.guest_user
    end
  end # class CryptIdent::SignIn
end
