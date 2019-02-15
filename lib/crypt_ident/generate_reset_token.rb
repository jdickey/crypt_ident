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
# @version 0.2.0
module CryptIdent
  # Generate a Password Reset Token
  #
  # Password Reset Tokens are useful for verifying that the person requesting a
  # Password Reset for an existing User is sufficiently likely to be the person
  # who Registered that User or, if not, that no compromise or other harm is
  # done.
  #
  # Typically, this is done by sending a link through email or other such medium
  # to the address previously associated with the User purportedly requesting
  # the Password Reset. `CryptIdent` *does not* automate generation or sending
  # of the email message. What it *does* provide is a method to generate a new
  # Password Reset Token to be embedded into an HTML anchor link within an email
  # that you construct, and then another method (`#reset_password`) to actually
  # change the password given a valid, correct token.
  #
  # It also implements an expiry system, such that if the confirmation of the
  # Password Reset request is not completed within a configurable time, that the
  # token is no longer valid (and so cannot be later reused by unauthorised
  # persons).
  #
  # This method *requires* a block, to which a `result` indicating success or
  # failure is yielded. That block **must** in turn call **both**
  # `result.success` and `result.failure` to handle success and failure results,
  # respectively. On success, the block yielded to by `result.success` is called
  # and passed a `user:` parameter, which is identical to the `user` parameter
  # passed in to `#generate_reset_token` *except* that the `:token` and
  # `:password_reset_expires_at` attributes have been updated to reflect the
  # token request. An updated record matching that `:user` Entity will also have
  # been saved to the Repository.
  #
  # On failure, the `result.failure` call will yield three parameters: `:code`,
  # `:current_user`, and `:name`, and will be set as follows:
  #
  # If the `:code` value is `:user_logged_in`, that indicates that the
  # `current_user` parameter to this method represented a Registered User. In
  # this event, the `:current_user` value passed in to the `result.failure` call
  # will be the same User Entity passed into the method, and the `:name` value
  # will be `:unassigned`.
  #
  # If the `:code` value is `:user_not_found`, the named User was not found in
  # the Repository. The `:current_user` parameter will be the Guest User Entity,
  # and the `:name` parameter to the `result.failure` block will be the
  # `user_name` value passed into the method.
  # @yieldparam result [Dry::Matcher::Evaluator] Indicates whether the attempt
  #               to generate a new Reset Token succeeded or failed. The lock
  #               **must** call **both** `result.success` and `result.failure`
  #               methods, where the block passed to `result.success` accepts a
  #               parameter for `user:`, which is a User Entity with the
  #               specified `name` value as well as non-`nil` values for its
  #               `:token` and `:password_reset_expires_at` attributes. The
  #               block passed to `result.failure` accepts parameters for
  #               `code:`, `current_user:`, and `name` as described above.
  # @yieldreturn (void) Use the `result.success` and `result.failure`
  #               method-call blocks to retrieve data from the method.
  #
  # @since 0.1.0
  # @authenticated Must not be Authenticated.
  # @param [String] user_name The name of the User for whom a Password Reset
  #                 Token is to be generated.
  # @param [User, Hash] current_user Entity representing the currently
  #                 Authenticated User Entity. This **must** be a Registered
  #                 User, either as an Entity or as a Hash of attributes.
  # @return (void)
  # @example Demonstrating a (refactorable) Controller Action Class #call method
  #
  #   def call(params)
  #     config = CryptIdent.config
  #     # Remember that reading an Entity stored in session data will in fact
  #     #   return a *Hash of its attribute values*. This is acceptable.
  #     other_params = { current_user: session[:current_user] }
  #     generate_reset_token(params[:name], other_params) do |result|
  #       result.success do |user:|
  #         @user = user
  #         flash[config.success_key] = 'Request for #{user.name} sent'
  #       end
  #       result.failure do |code:, current_user:, name:| do
  #         respond_to_error(code, current_user, name)
  #       end
  #     end
  #   end
  #
  #   private
  #
  #   def respond_to_error(code, current_user, name)
  #     # ...
  #   end
  # @session_data
  #   `:current_user` **must not** be a Registered User.
  # @ubiq_lang
  #   - Authentication
  #   - Guest User
  #   - Password Reset Token
  #   - Registered User
  def generate_reset_token(user_name, current_user: nil)
    other_params = { current_user: current_user }
    GenerateResetToken.new.call(user_name, other_params) do |result|
      yield result
    end
  end

  # Generate Reset Token for non-Authenticated User
  #
  # This class *is not* part of the published API.
  # @private
  class GenerateResetToken
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    LogicError = Class.new(RuntimeError)

    def initialize
      @current_user = nil
      @user_name = :unassigned
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
      current_user = @current_user || guest_user
      # This will convert a Hash of attributes to an Entity instance. It leaves
      # an actual Entity value unmolested.
      @current_user = guest_user.class.new(current_user)
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
      # will be `nil` if no match found
      CryptIdent.config.repository.find_by_name(user_name)
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
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :GenerateResetToken if Hanami.respond_to?(:env?)
end
