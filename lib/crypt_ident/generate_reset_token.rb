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
      @current_user = @repo = @user_name = :unassigned
    end

    def call(user_name, current_user: nil, repo: nil)
      init_ivars(user_name, current_user, repo)
      Success(user: updated_user)
    rescue LogicError => error
      # rubocop:disable Security/MarshalLoad
      error_data = Marshal.load(error.message)
      # rubocop:enable Security/MarshalLoad
      Failure(error_data)
    end

    private

    attr_reader :current_user, :repo, :user_name

    def init_ivars(user_name, current_user, repo)
      @current_user = current_user
      @repo = repo
      @user_name = user_name
    end

    def new_token
      token_length = CryptIdent.cryptid_config.token_bytes
      clear_text_token = SecureRandom.alphanumeric(token_length)
      Base64.strict_encode64(clear_text_token)
    end

    def update_repo(user)
      repo.update(user.id, updated_attribs)
    end

    def updated_attribs
      prea = Time.now + CryptIdent.cryptid_config.reset_expiry
      { token: new_token, password_reset_expires_at: prea }
    end

    def updated_user
      @repo = repo_from(repo)
      validate_current_user
      update_repo(user_by_name)
    end

    def user_by_name
      found = repo.find_by_name(user_name)
      return found.first unless found.empty?

      raise LogicError, user_not_found_error
    end

    def user_logged_in_error
      Marshal.dump(code: :user_logged_in, current_user: current_user,
                   name: :unassigned)
    end

    def user_not_found_error
      Marshal.dump(code: :user_not_found, current_user: current_user,
                   name: user_name)
    end

    # Reek sees a :reek:ControlParameter in `repo`. Ignoring.
    def repo_from(repo)
      repo || CryptIdent.cryptid_config.repository
    end

    def validate_current_user
      @current_user ||= repo.guest_user
      return current_user if current_user.guest_user?

      raise LogicError, user_logged_in_error
    end
  end
end
