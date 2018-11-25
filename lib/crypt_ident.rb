# frozen_string_literal: true

require 'bcrypt'

require 'crypt_ident/version'

require_relative './crypt_ident/config'
require_relative './crypt_ident/change_password'
require_relative './crypt_ident/sign_in'
require_relative './crypt_ident/sign_up'

# Include and interact with `CryptIdent` to add authentication to a
# Hanami controller action.
#
# Note the emphasis on *controller action*; this module interacts with session
# data, which is quite theoretically possible in an Interactor but practically
# *quite* the PITA. YHBW.
#
# @author Jeff Dickey
# @version 0.1.0
# FIXME: Disable :reek:UnusedParameters; we have not yet added code.
module CryptIdent
  include Hanami::Utils::ClassAttribute
  class_attribute :cryptid_config

  # Set configuration information at the class (actually, module) level.
  #
  # **IMPORTANT:** Even though we follow time-honoured convention
  # here and call the variable yielded by the `CryptIdent.configure_crypt_ident`
  # block `config`, settings *are not* being stored in an *instance variable*
  # called `@config`. That is *too likely* to conflict with something Important;
  # remember, we're a module, not a class, and good table manners are *also*
  # Important.
  #
  # This is normally run from the `controller.prepare` block inside your app's
  # `apps/<app name>/application.rb` file, where the default for `app_name` in a
  # Hanami app is `web`.
  #
  # @since 0.1.0
  # @authenticated Irrelevant; normally called during framework setup.
  # @return {CryptIdent::Config}
  # @example
  #   CryptIdent.configure_crypt_ident do |config| # show defaults
  #     config.error_key = :error
  #     config.guest_user = nil
  #     config.hashing_cost = 8
  #     config.repository = UserRepository.new
  #     config.guest_user = config.repository.guest_user
  #     config.reset_expiry = (24 * 60 * 60)
  #     config.session_expiry = 900
  #     config.success_key = :success
  #     config.token_bytes = 16
  #   end
  # @session_data Irrelevant; normally called during framework setup.
  # @ubiq_lang None; only related to demonstrated configuration settings.
  # @yieldparam [Struct] config Mutable Struct initialised to default config.
  # @yieldreturn [void]
  def self.configure_crypt_ident
    config = _starting_config
    yield config if block_given?
    @cryptid_config = Config.new(config.to_h)
  end

  # Get initial config settings for `.configure_crypt_ident`.
  #
  # This exists solely to get Flog's score down into the single digits.
  #
  # @private
  # @since 0.1.0
  # @return {CryptIdent::Config}
  def self._starting_config
    starting_config = @cryptid_config || Config.new
    hash = starting_config.to_h
    Struct.new(*hash.keys).new(*hash.values)
  end

  # Reset configuration information to default values.
  #
  # This **should** primarily be used during testing, and would normally be run
  # from a `before` block for a test suite.
  #
  # @since 0.1.0
  # @authenticated Irrelevant; normally called during framework setup.
  # @return {CryptIdent::Config}
  # @example Show how a modified configuration value is reset.
  #   CryptIdent.configure_crypt_ident do |config|
  #     config.hashing_cost = 20 # default 8
  #   end
  #   # ...
  #   foo = CryptIdent.configure_crypt_ident.hashing_cost # 20
  #   # ...
  #   CryptIdent.reset_crypt_ident_config
  #   foo == CryptIdent.configure_crypt_ident.hashing_cost # default, 8
  # @session_data Irrelevant; normally called during testing
  # @ubiq_lang None; only related to demonstrated configuration settings.
  def self.reset_crypt_ident_config
    self.cryptid_config = Config.new
  end

  ############################################################################ #

  # Persist a new User to a Repository based on passed-in attributes, where the
  # resulting Entity (on success) contains a  `:password_hash` attribute
  # containing the encrypted value of the Clear-Text Password passed in as the
  # `password` value within `attribs`.
  #
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. That block **must** in turn call **both**
  # `result.success` and `result.failure` to handle success and failure results,
  # respectively. On success, the block yielded to by `result.success` is called
  # and passed `config:` and `user:` parameters, which are the Config object
  # active while creating the new User, and the newly-created User Entity itself
  # respectively.
  #
  # If the call fails, the `result.success` block is yielded to, and passed
  # `config:` and `code:` parameters. The `config:` parameter is the active
  # configuration as described earlier for `result.success`. The `code:`
  # parameter will contain one of the following symbols:
  #
  # * `:current_user_exists` indicates that the method was called with a
  # `current_user` parameter that was neither `nil` nor the Guest User.
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
  #               required by the underlying database schema, as well as a
  #               clear-text `password` attribute which will be replaced in the
  #               created Entity/record by a `password_hash` attribute.
  # @param [User, nil] current_user Entity representing the current
  #               Authenticated User, or the Guest User. A value of `nil` is
  #               treated as though the Guest User had been specified.
  # @param [Hanami::Repository, nil] repo Repository to be used for accessing
  #               User data. A value of `nil` indicates that the default
  #               Repository specified in the Configuration should be used.
  # @return [User, Symbol] Entity representing created User on success, or a
  #               Symbol identifying the reason for failure.
  # @yieldparam result [Dry::Matcher::Evaluator] Indicates whether the attempt
  #               to create a new User succeeded or failed. Block **must**
  #               call **both** `result.success` and `result.failure` methods,
  #               where the block passed to `result.success` accepts parameters
  #               for `config:` (which is the active configuration for the call)
  #               and `user:` (which is the newly-created User Entity). The
  #               block passed to `result.failure` accepts parameters for
  #               `config:` (as before) and `code:`, which is a Symbol reporting
  #               the reason for the failure (as described above).
  # @example in a Controller Action Class
  #   def call(_params)
  #     sign_up(params, current_user: session[:current_user]) do |result|
  #       result.success do |config:, user:|
  #         @user = user
  #         message = "#{user.name} successfully created. You may sign in now."
  #         flash[config.success_key] = message
  #         redirect_to routes.root_path
  #       end
  #
  #       result.failure do |code:, config:|
  #         # `#error_message_for` is a method on the same class, not shown
  #         flash[config.failure_key] = error_message_for(code, params)
  #       end
  #     end
  #   end
  # @session_data
  #   `:current_user` **must not** be other than `nil` or the Guest User.
  # @ubiq_lang
  #   - Authentication
  #   - Clear-Text Password
  #   - Entity
  #   - Guest User
  #   - Repository
  #   - User
  def sign_up(attribs, current_user:, repo: nil)
    SignUp.new(repo).call(attribs, current_user: current_user) do |result|
      yield result
    end
  end

  # Attempt to Authenticate a User, passing in an Entity for that User (which
  # **must** contain a `password_hash` attribute), and a Clear-Text Password.
  # It also passes in the Current User.
  #
  # If the Current User is either `nil` or the Guest User, then Authentication
  # of the specified User Entity against the specified Password proceeds as
  # follows: The User Entity's `password_hash` attribute is used to attempt a
  # match against the passed-in Clear-Text Password. If and only if a match is
  # determined, the passed-in User Entity is returned, indicating success.
  # Otherwise, the method returns `nil`.
  #
  # If the Current User is the *same* User as that in the specified User Entity
  # (as compared by their attributes being equal), then Authentication proceeds
  # normally; if the incorrect Password is specified, the method will return
  # `nil` (and its client code can determine what to do from there).
  #
  # If the Current User is a User *other than* the Guest User or the User Entity
  # passed in, the method returns `nil` without attempting to Authenticate the
  # Clear-Text Password.
  #
  # On *success,* the Controller-level client code **must** set:
  #
  # * `session[:start_time]` to the current time as returned by `Time.now`;
  # * `session[:current_user]` to tne returned *Entity* for the successfully
  #   Authenticated User. This is to eliminate possible repeated reads of the
  #   Repository.
  #
  # On *failure,* the Controller-level client code **should** set:
  #
  # * `session[:start_time]` to some sufficiently-past time to *always* trigger
  #   `#session_expired?`; `Hanami::Utils::Kernel.Time(0)` does this quite well
  #   (returning midnight GMT on 1 January 1970, converted to local time).
  # * `session[:current_user]` to `nil` or the Guest User.
  #
  # @since 0.1.0
  # @authenticated Must not be Authenticated as a different User.
  # @param [User] user Entity representing a User to be Authenticated.
  # @param [String] password Claimed Clear-Text Password for the specified User.
  # @param [User, nil] current_user Entity representing the currently
  #               Authenticated User Entity; either `nil` or the Guest User if
  #               none.
  # @return [User, nil] See method descriptive text.
  # @example As in a Controller Action Class (which you'd refactor somewhat):
  #   def call(params)
  #     user = UserRepository.new.find_by_email(params[:email])
  #     guest_user = CryptIdent::configure_crypt_ident.guest_user
  #     return update_session_data(guest_user, 0) unless user
  #
  #     @user = sign_in(user, params[:password],
  #                     current_user: session[:current_user])
  #     if @user
  #       update_session_data(@user, Time.now)
  #     else
  #       update_session_data(guest_user, 0)
  #     end
  #   end
  #
  #   private
  #
  #   def update_session_data(user, time)
  #     session[:current_user] = user
  #     session[:start_time] == Hanami::Utils::Kernel.Time(time)
  #   end
  # @session_data
  #   `:current_user` **must not** be other than `nil` or the Guest User.
  # @ubiq_lang
  #   - Authenticated User
  #   - Authentication
  #   - Clear-Text Password
  #   - Entity
  #   - Guest User
  #   - User
  #
  # ----
  #
  def sign_in(user, password, current_user: nil)
    SignIn.new.call(user: user, password: password, current_user: current_user)
  end

  # Sign out a previously Authenticated User.
  #
  # The block is _required_ for this method; in it, you should either delete or
  # reset the `session[:current_user]` and `session[:start_time]` variables.
  #
  # If resetting the values, we **recommend** they be set to
  #
  # * `CryptIdent.configure_crypt_ident.guest_user` for
  #   `session[:current_user]` and
  # * `Hanami::Utils::Kernel.Time(0)` for `session[:start_time]`, which will set
  #   the timestamp to midnight on 1 January 1970 -- a value which should *far*
  #   exceed your session-expiry limit.
  #
  # Calling this method when no Current User has been Authenticated is virtually
  # idempotent; the only changes will be if you had reset session data in one
  # call and deleted it in the other, or vice versa. Either **should not** have
  # any impact on your application.
  #
  # @since 0.1.0
  # @authenticated Should be Authenticated.
  # @param [Block] _block Required block which will always be called; see
  #                earlier description.
  # @return (void)
  # @yieldparam [Config] config Immutable CryptIdent::Config instance with
  #                      currently-active configuration values.
  # @yieldreturn [void]
  #
  # @example Controller Action Class method example resetting values
  #   def call(_params)
  #     sign_out do
  #       session[:current_user] = CryptIdent.configure_crypt_ident.guest_user
  #       session[:start_time] = Hanami::Utils::Kernel.Time(0)
  #     end
  #   end
  #
  # @example Controller Action Class method example deleting values
  #   def call(_params)
  #     sign_out do
  #       session[:current_user] = nil
  #       session[:start_time] = nil
  #     end
  #   end
  #
  # @session_data
  #   See method description above.
  #
  # @ubiq_lang
  #   - Authenticated User
  #   - Authentication
  #   - Controller Action Class
  #   - Entity
  #   - Guest User
  #   - Interactor
  #   - Repository
  #
  def sign_out(&_block)
    yield CryptIdent.configure_crypt_ident
  end

  # Change an Authenticated User's password.
  #
  # To change an Authenticated User's password, an Entity for that User, the
  # current Clear-Text Password, and the new Clear-Text Password are required.
  # The method accepts an optional `repo` parameter to specify a Repository
  # instance to which the updated User Entity should be persisted; if none is
  # specified (i.e., if the parameter has its default value of `nil`), then the
  # `UserRepository` specified in the Configuration is used.
  #
  # If the passed-in `user` is the Guest User (or `nil`), the method returns
  # `:invalid_user` and no further action is taken.
  #
  # If the specified current Clear-Text Password cannot Authenticate against the
  # encrypted value within the `user` Entity, then the method returns
  # `:bad_password` and no further action is taken.
  #
  # If these checks pass, then a new Entity, identical to the passed-in `user`
  # *except* having a new value for its `password_hash`, is persisted to the
  # Repository specified either by the `repo` parameter or, if that is `nil`,
  # then the default Repository specified in the default configuration.
  #
  # If that Entity is successfully persisted, then this method will return that
  # Entity. If persistence fails, a `:repository_error` Symbol is returned to
  # indicate the error.
  #
  # @since 0.1.0
  # @authenticated Must Authenticate.
  # @param [User] user The User Entity from which to get the valid Encrypted
  #                 Password and other non-Password attributes
  # @param [String] current_password The current Clear-Text Password for the
  #                 specified Current User
  # @param [String] new_password The new Clear-Text Password to encrypt and add
  #                 to the returned Entity
  # @param [Object, nil] repo The Repository to which the updated User Entity is
  #                 to be persisted. If the default value of `nil`, then the
  #                 UserRepository specified in the default configuration is
  #                 used.
  # @return [User, Symbol] A User Entity with a new Encrypted Password value on
  #                 success, or a symbolic error identifier on failure.
  #
  # @example for a Controller Action Class
  #   def call(params)
  #     user = session[:current_user]
  #     result = change_password(user, params[:password], params[:new_password])
  #     @user = result if result_ok?(result)
  #   end
  #
  #   private
  #
  #   BAD_PASSWORD_MESSAGE = 'Invalid current password supplied.'
  #   INVALID_USER_MESSAGE = 'Not an Authenticated User.'
  #   private_constant :BAD_PASSWORD_MESSAGE, :INVALID_USER_MESSAGE
  #
  #   def result_ok?(result)
  #     key = CryptIdent.configure_crypt_ident.error_key
  #     case result
  #     when :bad_password then flash[key] = BAD_PASSWORD_MESSAGE
  #     when :invalid_user then flash[key] = INVALID_USER_MESSAGE
  #     else return true
  #     end
  #     false
  #   end
  #
  # @session_data
  #   Implies that `:current_user` **must** be an Entity for a Registered User
  # @ubiq_lang
  #   - Authentication
  #   - Clear-Text Password
  #   - Encrypted Password
  #   - Entity
  #   - Guest User
  #   - Registered User
  #   - Repository
  def change_password(user, current_password, new_password, repo: nil)
    ChangePassword.new(config: CryptIdent.cryptid_config, repo: repo,
                       user: user)
                  .call(current_password, new_password)
  end

  ############################################################################ #

  # Request a Password Reset Token
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
  # that you construct.
  #
  # It also implements an expiry system, such that if the confirmation of the
  # Password Reset request is not completed within a configurable time, that the
  # token is no longer valid (and so cannot be later reused by unauthorised
  # persons).
  #
  # @since 0.1.0
  # @authenticated Must not be Authenticated.
  # @param [String] user_name The name of the User for whom a Password Reset
  #                 Token is to be generated.
  # @return [Symbol, true] True on success or error identifier on failure.
  # @example
  #   def call(params)
  #     send_reset_email if valid_request?
  #   end
  #
  #   private
  #
  #   def send_result_email
  #     # will use @user_name and @token to generate and send email
  #   end
  #
  #   def valid_request?(params)
  #     logged_in_error = 'Cannot request password reset while logged in!'
  #     not_found_error = 'Cannot find specified user in repository'
  #     @user_name = params[:name] || 'Unknown User'
  #     @token = case generate_reset_token(user_name)
  #     when :user_logged_in then error!(logged_in_error)
  #     when :user_not_found then error!(not_found_error)
  #     end
  #   end
  # @session_data
  #   `:current_user` **must not** be other than `nil` or the Guest User.
  # @ubiq_lang
  #   - Authentication
  #   - Password Reset Token
  #   - Registered User
  #
  def generate_reset_token(user_name)
    # To be implemented.
  end

  # Reset the password for the User associated with a Password Reset Token.
  #
  # After a Password Reset Token has been
  # [generated](#generate_reset_token-instance_method) to a User, that User
  # would then exercise the Client system and perform a Password Reset.
  #
  # Again, this differs from a
  # [Change Password](#change_password-instance-method) activity since the User
  # in question *is not Authenticated* at the time of the action.
  #
  # The `#reset_password` method is called with a Password Reset Token, a new
  # Clear-Text Password, and a Clear-Text Password Confirmation.
  #
  # If the token is invalid or has expired, `reset_password` returns a value of
  # `:invalid_token`.
  #
  # If the new password and confirmation do not match, `reset_password` returns
  # `:mismatched_password`.
  #
  # If the new Clear-Text Password and its confirmation match, then the
  # value of that new Encrypted Password is returned, and the Repository record
  # for that Registered User is updated to include the new Encrypted Password.
  #
  # In no event are session values, including the Current User, changed. After a
  # successful Password Reset, the User must Authenticate as usual.
  #
  # @todo FIXME: API and docs *not yet finalised!*
  # @since 0.1.0
  # @authenticated Must not be Authenticated.
  # @param [String] token The Password Reset Token previously communicated to
  #                       the User.
  # @param [String] new_password New Clear-Text Password to encrypt and add to
  #                 return value
  # @param [String] confirmation Clear-Text Password Confirmation.
  # @return [Symbol, true] True on success or error identifier on failure.
  # @example
  #   def call(params)
  #     return unless params_valid?(params)
  #
  #     flash[config.success_key] = 'You have reset your password. Please ' \
  #                                 'sign in.'
  #     redirect_to config.root_path
  #   end
  #
  #   private
  #
  #   def params_valid?(params)
  #     invalid_token_error = 'Invalid or expired token. Request reset again.'
  #     mismatch_error = 'New password and confirmation do not match'
  #     result = reset_password(params[:token], params[:new_password],
  #                             params[:confirmation])
  #     case result
  #     when :invalid_token then error!(invalid_token_error)
  #     when :mismatched_password then error!(mismatch_error)
  #     end
  #   end
  # @session_data
  #   `:current_user` **must not** be other than `nil` or the Guest User.
  # @ubiq_lang
  #   - Authentication
  #   - Clear-Text Password
  #   - Clear-Text Password Confirmation
  #   - Encrypted Password
  #   - Password Reset Token
  #   - Registered User
  #
  def reset_password(token, new_password, confirmation)
    # To be implemented.
  end

  ############################################################################ #

  # Restart the Session Expiration timestamp mechanism, to avoid prematurely
  # signing out a User.
  #
  # @todo FIXME: API and docs *not yet finalised!*
  # @since 0.1.0
  # @authenticated Must be Authenticated.
  # @return (void)
  # @example
  #   def validate_session
  #     return restart_session_counter unless session_expired?
  #
  #     # ... sign out and redirect appropriately ...
  #   end
  # @session_data
  #   `:current_user` **must** be an Entity for a Registered User on entry
  #   `:start_time`   set to `Time.now` on exit
  # @ubiq_lang
  #   - Authentication
  #   - Session Expiration
  #
  def restart_session_counter
    # To be implemented.
  end

  # Determine whether the Session has Expired due to User inactivity.
  #
  # This is determined by comparing the current time as reported by `Time.now`
  # to the timestamp resulting from adding `session[:start_time]` and
  # `config.session_expiry`.
  #
  # Will return `false` if `session[:current_user]` is `nil` or has the value
  # specified by `config.guest_user`.
  #
  # @todo FIXME: API and docs *not yet finalised!*
  # @since 0.1.0
  # @authenticated Must be Authenticated.
  # @return [Boolean]
  # @example
  #   def validate_session
  #     return restart_session_counter unless session_expired?
  #
  #     # ... sign out and redirect appropriately ...
  #   end
  # @session_data
  #   `:current_user` **must** be an Entity for a Registered User on entry
  #   `:start_time`   read during determination of expiry status
  # @ubiq_lang
  #   - Authentication
  #   - Session Expiration
  #
  def session_expired?
    # To be implemented.
  end
end
