# frozen_string_literal: true

require 'bcrypt'

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

# Authenticated-User Password-change logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Reworked password-change logic for `CryptIdent`, per Issue #9.
  #
  # This class *is not* part of the published API.
  # @private
  class ChangePassword
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    # Reek complains about :reek:ControlParameter for `repo`. Oh, well.
    def initialize(config:, repo:, user:)
      @repo = repo || config.repository
      @user = user
      @updated_attribs = nil
    end

    def call(current_password, new_password)
      verify_preconditions(current_password)

      # Success(user: update(new_password))
      success_result(new_password)
    rescue LogicError => error
      failure_result(error.message)
    end

    private

    attr_reader :repo, :updated_attribs, :user

    LogicError = Class.new(RuntimeError)
    private_constant :LogicError

    def failure_result(error_message)
      Failure(code: error_message.to_sym)
    end

    def raise_logic_error(code)
      raise LogicError, code.to_s
    end

    def success_result(new_password)
      Success(user: update(new_password))
    end

    def update(new_password)
      update_attribs(new_password)
      repo.update(user.id, updated_attribs)
    end

    def update_attribs(new_password)
      new_hash = ::BCrypt::Password.create(new_password)
      @updated_attribs = { password_hash: new_hash, updated_at: Time.now }
    end

    def valid_password?(password)
      user.password_hash == password
    end

    def valid_user?
      _ = user.password_hash
      !user.guest_user?
    rescue NoMethodError
      false
    end

    def verify_preconditions(current_password)
      raise_logic_error :invalid_user unless valid_user?
      raise_logic_error :bad_password unless valid_password?(current_password)
    end
  end
end
