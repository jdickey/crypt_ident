# frozen_string_literal: true

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
  # Attempt to Authenticate a User, passing in an Entity for that User (which
  # **must** contain a `password_hash` attribute), and a Clear-Text Password.
  # It also passes in the Current User.
  #
  # If the Current User is not a Registered User, then Authentication of the
  # specified User Entity against the specified Password is accomplished by
  # comparing the User Entity's `password_hash` attribute to the passed-in
  # Clear-Text Password.
  #
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. That block **must** in turn call **both**
  # `result.success` and `result.failure` to handle success and failure results,
  # respectively. On success, the block yielded to by `result.success` is called
  # and passed a `user:` parameter, which is the Authenticated User (and is the
  # same Entity as the `user` parameter passed in to `#sign_in`).
  #
  # On failure, the `result.failure` call will yield a `code:` parameter to its
  # block, which indicates the cause of failure as follows:
  #
  # If the specified password *did not* match the passed-in `user` Entity, then
  # the `code:` for failure will be `:invalid_password`.
  #
  # If the specified `user` was not a Registered User, then the `code:` for
  # failure will be `:user_is_guest`.
  #
  # If the specified `current_user` is *neither* the Guest User *nor* the `user`
  # passed in as a parameter to `#sign_in`, then the `code:` for failure will be
  # `:illegal_current_user`.
  #
  # On *success,* the Controller-level client code **must** set:
  #
  # * `session[:expires_at]` to the expiration time for the session. This is
  #   ordinarily computed by adding the current time as returned by `Time.now`
  #   to the `:session_expiry` value in the current configuration.
  # * `session[:current_user]` to tne returned *Entity* for the successfully
  #   Authenticated User. This is to eliminate possible repeated reads of the
  #   Repository.
  #
  # On *failure,* the Controller-level client code **should** set:
  #
  # * `session[:expires_at]` to some sufficiently-past time to *always* trigger
  #   `#session_expired?`; `Hanami::Utils::Kernel.Time(0)` does this quite well
  #   (returning midnight GMT on 1 January 1970, converted to local time).
  # * `session[:current_user]` to either `nil` or the Guest User.
  #
  # @since 0.1.0
  # @authenticated Must not be Authenticated as a different User.
  # @param [User] user_in Entity representing a User to be Authenticated.
  # @param [String] password Claimed Clear-Text Password for the specified User.
  # @param [User, nil] current_user Entity representing the currently
  #               Authenticated User Entity; either `nil` or the Guest User if
  #               none.
  # @return (void) Use the `result` yield parameter to determine results.
  # @yieldparam result [Dry::Matcher::Evaluator] Indicates whether the attempt
  #               to Authenticate a User succeeded or failed. Block **must**
  #               call **both** `result.success` and `result.failure` methods,
  #               where the block passed to `result.success` accepts a parameter
  #               for `user:` (which is the newly-created User Entity). The
  #               block passed to `result.failure` accepts a parameter for
  #               `code:`, which is a Symbol reporting the reason for the
  #               failure (as described above).
  # @yieldreturn [void]
  # @example As in a Controller Action Class (which you'd refactor somewhat):
  #   def call(params)
  #     user = UserRepository.new.find_by_email(params[:email])
  #     guest_user = CryptIdent.config.guest_user
  #     return update_session_data(guest_user, 0) unless user
  #
  #     current_user = session[:current_user]
  #     config = CryptIdent.config
  #     sign_in(user, params[:password], current_user: current_user) do |result|
  #       result.success do |user:|
  #         @user = user
  #         update_session_data(user, Time.now)
  #         flash[config.success_key] = "User #{user.name} signed in."
  #         redirect_to routes.root_path
  #       end
  #
  #       result.failure do |code:|
  #         update_session_data(guest_user, config, 0)
  #         flash[config.error_key] = error_message_for(code)
  #       end
  #     end
  #
  #   private
  #
  #   def error_message_for(code)
  #     # ...
  #   end
  #
  #   def update_session_data(user, time)
  #     session[:current_user] = user
  #     expiry = Time.now + CryptIdent.config.session_expiry
  #     session[:expires_at] == Hanami::Utils::Kernel.Time(expiry)
  #   end
  # @session_data
  #   `:current_user` **must not** be a Registered User
  # @ubiq_lang
  #   - Authenticated User
  #   - Authentication
  #   - Clear-Text Password
  #   - Entity
  #   - Guest User
  #   - Registered User
  #
  def sign_in(user_in, password, current_user: nil)
    params = { user: user_in, password: password, current_user: current_user }
    SignIn.new.call(params) { |result| yield result }
  end

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
    # rubocop:disable Naming/RescuedExceptionsVariableName
    def call(user:, password:, current_user: nil)
      set_ivars(user, password, current_user)
      validate_call_params
      Success(user: user)
    rescue LogicError => err
      Failure(code: err.message.to_sym)
    end
    # rubocop:enable Naming/RescuedExceptionsVariableName

    private

    attr_reader :current_user, :password, :user

    LogicError = Class.new(RuntimeError)
    private_constant :LogicError

    def illegal_current_user?
      !current_user.guest? && !same_user?
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
      guest_user = CryptIdent.config.guest_user
      current ||= guest_user
      @current_user = guest_user.class.new(current)
    end

    def validate_call_params
      raise LogicError, 'user_is_guest' if user.guest?
      raise LogicError, 'illegal_current_user' if illegal_current_user?

      verify_matching_password
    end

    def verify_matching_password
      match = password_comparator == password
      raise LogicError, 'invalid_password' unless match
    end
  end
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :SignIn if Hanami.respond_to?(:env?)
end
