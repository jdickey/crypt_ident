# frozen_string_literal: true

require 'crypt_ident/version'

require_relative './crypt_ident/config'
require_relative './crypt_ident/change_password'
require_relative './crypt_ident/generate_reset_token'
require_relative './crypt_ident/reset_password'
require_relative './crypt_ident/session_expired'
require_relative './crypt_ident/sign_in'
require_relative './crypt_ident/sign_out'
require_relative './crypt_ident/sign_up'
require_relative './crypt_ident/update_session_expiry'

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
  # Persist a new User to a Repository based on passed-in attributes, where the
  # resulting Entity (on success) contains a  `:password_hash` attribute
  # containing the encrypted value of a **random** Clear-Text Password; any
  # `password` value within `attribs` is ignored.
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
  #     guest_user = CryptIdent::cryptid_config.guest_user
  #     return update_session_data(guest_user, 0) unless user
  #
  #     current_user = session[:current_user]
  #     config = CryptId.cryptid_config
  #     sign_in(user, params[:password], current_user: current_user) do |result|
  #       result.success do |user:|
  #         @user = user
  #         update_session_data(user, config, Time.now)
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
  #   def update_session_data(user, config, time)
  #     session[:current_user] = user
  #     expiry = Time.now + config.session_expiry
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

  # Sign out a previously Authenticated User.
  #
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. (Presently, any call to `#sign_out` results in success.)
  # That block **must** in turn call **both** `result.success` and
  # `result.failure` (even though no failure is implemented) to handle success
  # and failure results, respectively. On success, the block yielded to by
  # `result.success` is called and passed a `config:` parameter, which is simply
  # the value returned from `CryptIdent.cryptid_config` with no modifier block),
  # It may safely be ignored.
  #
  # @since 0.1.0
  # @authenticated Should be Authenticated.
  # @param [User, `nil`] current_user Entity representing the currently
  #               Authenticated User Entity. This **should** be a Registered
  #               User.
  # @return (void)
  # @yieldparam result [Dry::Matcher::Evaluator] Normally, used to report
  #               whether a method succeeded or failed. The block **must**
  #               call **both** `result.success` and `result.failure` methods.
  #               In practice, parameters to both may presently be safely
  #               ignored; `config` is passed to `success` as a convenience.
  # @yieldreturn [void]
  #
  # @example Controller Action Class method example resetting values
  #   def call(_params)
  #     sign_out(session[:current_user]) do |result|
  #       result.success do |config|
  #         session[:current_user] = config.guest_user
  #         session[:expires_at] = Hanami::Utils::Kernel.Time(0)
  #       end
  #
  #       result.failure { next }
  #     end
  #   end
  #
  # @example Controller Action Class method example deleting values
  #   def call(_params)
  #     sign_out(session[:current_user]) do |result|
  #       result.success do |config|
  #         session[:current_user] = nil
  #         session[:expires_at] = nil
  #       end
  #
  #       result.failure { next }
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
  def sign_out(current_user:)
    SignOut.new.call(current_user: current_user) { |result| yield result }
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
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. That block **must** in turn call **both**
  # `result.success` and `result.failure` to handle success and failure results,
  # respectively. On success, the block yielded to by `result.success` is called
  # and passed a `user:` parameter, which is identical to the `user` parameter
  # passed in to `#change_password` *except* that the `:password_hash` attribute
  # has been updated to reflect the changed password. The updated value for the
  # encrypted password will also have been saved to the Repository.
  #
  # On failure, the `result.failure` call will yield a `code:` parameter to its
  # block, which indicates the cause of failure as follows:
  #
  # If the specified password *did not* match the passed-in `user` Entity, then
  # the `code:` for failure will be `:bad_password`.
  #
  # If the specified `user` was *other than* a User Entity representing a
  # Registered User, then the `code:` for failure will be `:invalid_user`.
  #
  # Note that no check for the Current User is done here; this method trusts the
  # Controller Action Class that (possibly indirectly) invokes it to guard that
  # contingency properly.
  #
  # @since 0.1.0
  # @authenticated Must be Authenticated.
  # @param [User] user_in The User Entity from which to get the valid Encrypted
  #                 Password and other non-Password attributes
  # @param [String] current_password The current Clear-Text Password for the
  #                 specified User
  # @param [String] new_password The new Clear-Text Password to encrypt and add
  #                 to the returned Entity, and persist to the Repository
  # @return (void) Use the `result` yield parameter to determine results.
  # @yieldparam result [Dry::Matcher::Evaluator] Indicates whether the attempt
  #               to create a new User succeeded or failed. Block **must**
  #               call **both** `result.success` and `result.failure` methods,
  #               where the block passed to `result.success` accepts parameters
  #               for `config:` (which is the active configuration for the call)
  #               and `user:` (which is the newly-created User Entity). The
  #               block passed to `result.failure` accepts parameters for
  #               `config:` (as before) and `code:`, which is a Symbol reporting
  #               the reason for the failure (as described above).
  # @yieldreturn (void) Use the `result.success` and `result.failure`
  #               method-call blocks to retrieve data from the method.
  #
  # @example for a Controller Action Class (refactor in real use; demo only)
  #   def call(params)
  #     user_in = session[:current_user]
  #     error_code = :unassigned
  #     config = CryptIdent.cryptid_config
  #     change_password(user_in, params[:password],
  #                     params[:new_password]) do |result|
  #       result.success do |user:|
  #         @user = user
  #         flash[config.success_key] = "User #{user.name} password changed."
  #         redirect_to routes.root_path
  #       end
  #       result.failure do |code:|
  #         flash[config.error_key] = error_message_for(code)
  #       end
  #     end
  #   end
  #
  #   private
  #
  #   def error_message_for(code)
  #     # ...
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
  def change_password(user_in, current_password, new_password)
    new_params = { config: CryptIdent.config, user: user_in }
    call_params = [current_password, new_password]
    ChangePassword.new(new_params).call(*call_params) { |result| yield result }
  end

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
  # @param [User]   current_user Entity representing the currently
  #                 Authenticated User Entity. This **must** be a Registered
  #                 User.
  # @return (void)
  # @example Demonstrating a (refactorable) Controller Action Class #call method
  #
  #   def call(params)
  #     config = CryptIdent.cryptid_config
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
  #   - Password Reset Token
  #   - Registered User
  def generate_reset_token(user_name, current_user: nil)
    other_params = { current_user: current_user }
    GenerateResetToken.new.call(user_name, other_params) do |result|
      yield result
    end
  end

  # Reset the password for the User associated with a Password Reset Token.
  #
  # After a Password Reset Token has been
  # [generated](#generate_reset_token-instance_method) and sent to a User, that
  # User would then exercise the Client system and perform a Password Reset.
  #
  # Calling `#reset_password` is different than calling `#change_password` in
  # one vital respect: with `#change_password`, the User involved **must** be
  # the Current User (as presumed by passing the appropriate User Entity in as
  # the `current_user:` parameter), whereas `#reset_password` **must not** be
  # called with *any* User other than the Guest User as the `current_user:`
  # parameter (and, again presumably, the Current User for the session). How can
  # we assure ourselves that the request is legitimate for a specific User? By
  # use of the Token generated by a previous call to `#generate_reset_token`,
  # which is used _in place of_ a User Name for this request.
  #
  # Given a valid set of parameters, and given that the updated User is
  # successfully persisted, the method calls the **required** block with a
  # `result` whose `result.success` matcher is yielded a `user:` parameter with
  # the updated User as its value.
  #
  # NOTE: Each of the error returns documented below calls the **required**
  # block with a `result` whose `result.failure` matcher is yielded a `code:`
  # parameter as described; a `config:` parameter of the active
  # [_Configuration_](#configuration) (including the Repository used to retrieve
  # the relevant User record); and a `token:` parameter that has the same value
  # as the passed-in `token` parameter.
  #
  # If the passed-in `token` parameter matches the `token` field of a record in
  # the Repository *and* that Token is determined to have Expired, then the
  # `code:` parameter mentioned earlier will have the value `:expired_token`.
  #
  # If the passed-in `token` parameter *does not* match the `token` field of any
  # record in the Repository, then the `code:` parameter will have the value
  # `:token_not_found`.
  #
  # If the passed-in `current_user:` parameter is a Registered User, then the
  # `code:` parameter will have the value `:invalid_current_user`.
  #
  # In no event are session values, including the Current User, changed. After a
  # successful Password Reset, the User must Authenticate as usual.
  #
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
  # @param [String] token The Password Reset Token previously communicated to
  #                       the User.
  # @param [String] new_password New Clear-Text Password to encrypt and add to
  #                 return value
  # @return (void)
  # @example
  #   def call(params)
  #     reset_password(params[:token], params[:new_password],
  #                    current_user: session[:current_user]) do |result
  #       result.success do |user:|
  #         @user = user
  #         message = "Password for #{user.name} successfully reset."
  #         config = CryptIdent.cryptid_config
  #         flash[config.success_key] = message
  #         redirect_to routes.root_path
  #       end
  #       result.failure do |code:, config:, token:|
  #         flash[config.failure_key] = failure_message_for(code, config, token)
  #       end
  #     end
  #   end
  #
  #   private
  #
  #   def failure_message_for(code, config, token)
  #     # ...
  #   end
  # @session_data
  #   `:current_user` **must not** be a Registered User.
  # @ubiq_lang
  #   - Authentication
  #   - Clear-Text Password
  #   - Encrypted Password
  #   - Password Reset Token
  #   - Registered User
  #
  def reset_password(token, new_password, current_user: nil)
    other_params = { current_user: current_user }
    ResetPassword.new.call(token, new_password, other_params) do |result|
      yield result
    end
  end

  # Determine whether the Session has Expired due to User inactivity.
  #
  # This is one of two methods in `CryptIdent` (the other being
  # [`#update_session_expiry?`](#update_session_expiry)) which *does not* follow
  # the `result`/success/failure [monad workflow](#interfaces). This is because
  # there is no success/failure division in the workflow. Calling the method
  # determines if the Current User session has Expired. If the passed-in
  # `:current_user` is a Registered User, then this will return `true` if the
  # current time is *later than* the passed-in `:expires_at` value; for the
  # Guest User, it should always return `false`. (Guest User sessions never
  # expire; after all, what would you change the session state to?).
  #
  # The client code is responsible for applying these values to its own actual
  # session data, as described by the sample session-management code shown in
  # the README.
  #
  # @param [Hash] session_data The Rack session data of interest to the method.
  #               If the `:current_user` entry is defined, it **must** be either
  #               a User Entity or `nil`, signifying the Guest User. If the
  #               `:expires_at` entry is defined, its value in the returned Hash
  #               *will* be different.
  #
  # @since 0.1.0
  # @authenticated Must be Authenticated.
  # @return [Boolean]
  # @example As used in module included by Controller Action Class (see README)
  #   def validate_session
  #     updates = update_session_expiry(session)
  #     if !session_expired?(session)
  #       session[:expires_at] = updates[:expires_at]
  #       return
  #     end
  #
  #     # ... sign out and redirect appropriately ...
  #   end
  # @session_data
  #   `:current_user` **must** be an Entity for a Registered User on entry
  #   `:expires_at`   read during determination of expiry status
  # @ubiq_lang
  #   - Authentication
  #   - Current User
  #   - Guest User
  #   - Registered User
  #   - Session Expiration
  #
  def session_expired?(session_data = {})
    SessionExpired.new.call(session_data)
  end

  # Generate a Hash containing an updated Session Expiration timestamp, which
  # can then be used for session management.
  #
  # This is one of two methods in `CryptIdent` (the other being
  # [`#session_expired?`](#session-expired)) which *does not* follow the
  # `result`/success/failure [monad workflow](#interfaces). This is because
  # there is no success/failure division in the workflow. Calling the method
  # only makes sense if there is a Registered User as the Current User, but *all
  # this method does* is build a Hash with `:current_user` and `:expires_at`
  # entries. The returned `:current_user` is the passed-in `:current_user` if a
  # Registered User, or the Guest User if not. The returned `:updated_at` value,
  # for a Registered User, is the configured Session Expiry added to the current
  # time, and for the Guest User, a time far enough in the future that any call
  # to `#session_expired?` will be highly unlikely to ever return `true`.
  #
  # The client code is responsible for applying these values to its own actual
  # session data, as described by the sample session-management code shown in
  # the README.
  #
  # @param [Hash] session_data The Rack session data of interest to the method.
  #               If the `:current_user` entry is defined, it **must** be either
  #               a User Entity or `nil`, signifying the Guest User. If the
  #               `:expires_at` entry is defined, its value in the returned Hash
  #               *will* be different.
  # @since 0.1.0
  # @authenticated Must be Authenticated.
  # @return [Hash] A `Hash` with entries to be used to update session data.
  #                `expires_at` will have a value of the current time plus the
  #                configuration-specified `session_expiry` offset *if* the
  #                supplied `:current_user` value is a Registered User;
  #                otherwise it will have a value far enough in advance of the
  #                current time (e.g., by 100 years) that the
  #                `#session_expired?` method is highly unlikely to ever return
  #                `true`. The `:current_user` value will be the passed-in
  #                `session_data[:current_user]` value if that represents a
  #                Registered User, or the Guest User otherwise.
  #
  # @example As used in module included by Controller Action Class (see README)
  #   def validate_session
  #     updates = update_session_expiry(session)
  #     if !session_expired?(session)
  #       session[:expires_at] = updates[:expires_at]
  #       return
  #     end
  #
  #     # ... sign out and redirect appropriately ...
  #   end
  # @session_data
  #   `:current_user` **must** be a User Entity or `nil` for the Guest User
  #   `:expires_at`   set to the session-expiration time on exit, which will be
  #                   arbitrarily far in the future for the Guest User.
  # @ubiq_lang
  #   - Authentication
  #   - Guest User
  #   - Registered User
  #   - Session Expiration
  #   - User
  #
  def update_session_expiry(session_data = {})
    UpdateSessionExpiry.new(CryptIdent.config).call(session_data)
  end
end
