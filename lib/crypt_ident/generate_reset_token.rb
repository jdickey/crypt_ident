# frozen_string_literal: true

require 'base64'

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
  # Generate Reset Token for non-Authenticated User
  #
  # This class *is not* part of the published API.
  # @private
  class GenerateResetToken
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    LogicError = Class.new(RuntimeError)

    def initialize
      @current_user = @user_name = :unassigned
    end

    def call(user_name, current_user: nil)
      init_ivars(user_name, current_user)
      Success(user: updated_user)
    rescue LogicError => error
      # rubocop:disable Security/MarshalLoad
      error_data = Marshal.load(error.message)
      # rubocop:enable Security/MarshalLoad
      Failure(error_data)
    end

    private

    attr_reader :current_user, :user_name

    def current_user_or_guest
      guest_user = CryptIdent.config.repository.guest_user
      @current_user = guest_user if [nil, :unassigned].include?(@current_user)
      @current_user
    end

    def init_ivars(user_name, current_user)
      @current_user = current_user
      @user_name = user_name
    end

    def new_token
      token_length = CryptIdent.config.token_bytes
      clear_text_token = SecureRandom.alphanumeric(token_length)
      Base64.strict_encode64(clear_text_token)
    end

    def update_repo(user)
      CryptIdent.config.repository.update(user.id, updated_attribs)
    end

    def updated_attribs
      prea = Time.now + CryptIdent.config.reset_expiry
      { token: new_token, password_reset_expires_at: prea }
    end

    def updated_user
      validate_current_user
      update_repo(user_by_name)
    end

    def find_user_by_name
      found = CryptIdent.config.repository.find_by_name(user_name)
      found.first # will be `nil` if no match found
    end

    def user_by_name
      found_user = find_user_by_name
      raise LogicError, user_not_found_error unless found_user

      found_user
    end

    def user_logged_in_error
      Marshal.dump(code: :user_logged_in, current_user: current_user,
                   name: :unassigned)
    end

    def user_not_found_error
      Marshal.dump(code: :user_not_found, current_user: current_user,
                   name: user_name)
    end

    def validate_current_user
      return current_user if current_user_or_guest.guest?

      raise LogicError, user_logged_in_error
    end
  end
end
