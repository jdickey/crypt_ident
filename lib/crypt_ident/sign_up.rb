# frozen_string_literal: true

require 'securerandom'

require 'bcrypt'

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

# Include and interact with `CryptIdent` to add authentication to a
# Hanami controller action.
#
# Note the emphasis on *controller action*; this module interacts with session
# data, which is quite theoretically possible in an Interactor but practically
# *quite* the PITA. YHBW.
#
# @author Jeff Dickey
# @version 0.2.2
module CryptIdent
  # Persist a new User to a Repository based on passed-in attributes, where the
  # resulting Entity (on success) contains a  `:password_hash` attribute
  # containing the encrypted value of a **random** Clear-Text Password; any
  # `password` value within `attribs` is ignored.
  #
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. That block **must** in turn call **both**
  # `result.success` and `result.failure` to handle success and failure results,
  # respectively. On success, the block yielded to by `result.success` is called
  # and passed a `user:` parameter, which is the newly-created User Entity.
  #
  # If the call fails, the `result.success` block is yielded to, and passed a
  # `code:` parameter, which will contain one of the following symbols:
  #
  # * `:current_user_exists` indicates that the method was called with a
  # Registered User as the `current_user` parameter.
  # * `:user_already_created` indicates that the specified `name` attribute
  # matches a record that already exists in the underlying Repository.
  # * `:user_creation_failed` indicates that the Repository was unable to create
  # the new User for some other reason, such as an internal error.
  #
  # **NOTE** that the incoming `params` are expected to have been whitelisted at
  # the Controller Action Class level.
  #
  # @since 0.1.0
  # @authenticated Must not be Authenticated.
  # @param [Hash] attribs Hash-like object of attributes for new User Entity and
  #               record. **Must** include `name` and  any other attributes
  #               required by the underlying database schema. Any `password`
  #               attribute will be ignored.
  # @param [User, nil] current_user Entity representing the current
  #               Authenticated User, or the Guest User. A value of `nil` is
  #               treated as though the Guest User had been specified.
  # @return (void) Use the `result` yield parameter to determine results.
  # @yieldparam result [Dry::Matcher::Evaluator] Indicates whether the attempt
  #               to create a new User succeeded or failed. Block **must**
  #               call **both** `result.success` and `result.failure` methods,
  #               where the block passed to `result.success` accepts a parameter
  #               for `user:` (which is the newly-created User Entity). The
  #               block passed to `result.failure` accepts a parameter for
  #               `code:`, which is a Symbol reporting the reason for the
  #               failure (as described above).
  # @example in a Controller Action Class
  #   def call(_params)
  #     sign_up(params, current_user: session[:current_user]) do |result|
  #       result.success do |user:|
  #         @user = user
  #         message = "#{user.name} successfully created. You may sign in now."
  #         flash[CryptIdent.config.success_key] = message
  #         redirect_to routes.root_path
  #       end
  #
  #       result.failure do |code:|
  #         # `#error_message_for` is a method on the same class, not shown
  #         failure_key = CryptIdent.config.failure_key
  #         flash[failure_key] = error_message_for(code, params)
  #       end
  #     end
  #   end
  # @session_data
  #   `:current_user` **must not** be a Registered User.
  # @ubiq_lang
  #   - Authentication
  #   - Clear-Text Password
  #   - Entity
  #   - Guest User
  #   - Registered User
  def sign_up(attribs, current_user:)
    SignUp.new.call(attribs, current_user: current_user) do |result|
      yield result
    end
  end

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
      guest_user = CryptIdent.config.guest_user
      user ||= guest_user
      !guest_user.class.new(user).guest?
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
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :SignUp if Hanami.respond_to?(:env?)
end
