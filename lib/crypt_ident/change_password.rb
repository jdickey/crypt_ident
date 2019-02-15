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
# @version 0.2.0
module CryptIdent
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
  #               where the block passed to `result.success` accepts a parameter
  #               for `user:` (which is the newly-created User Entity). The
  #               block passed to `result.failure` accepts a parameter for
  #               `code:`, which is a Symbol reporting the reason for the
  #               failure (as described above).
  # @yieldreturn (void) Use the `result.success` and `result.failure`
  #               method-call blocks to retrieve data from the method.
  #
  # @example for a Controller Action Class (refactor in real use; demo only)
  #   def call(params)
  #     user_in = session[:current_user]
  #     error_code = :unassigned
  #     config = CryptIdent.config
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
    call_params = [current_password, new_password]
    ChangePassword.new(user: user_in).call(*call_params) do |result|
      yield result
    end
  end

  # Include and interact with `CryptIdent` to add authentication to a
  # Hanami controller action.
  #
  # This class *is not* part of the published API.
  # @private
  class ChangePassword
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    def initialize(user:)
      @repo = CryptIdent.config.repository
      @user = user_from_param(user)
    end

    def call(current_password, new_password)
      verify_preconditions(current_password)

      success_result(new_password)
    rescue LogicError => error
      failure_result(error.message)
    end

    private

    attr_reader :repo, :user

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
      updated_attribs = update_attribs(new_password)
      repo.update(user.id, updated_attribs)
    end

    # The `user` param *might* have come from `Rack::Session` data, which
    # doesn't support Ruby objects beyond native JSON types. Fortunately
    # a) the definitions of equality and identity for two Entities compare
    #    attribute values only; and
    # b) Hanami Entities can be freely *and implicitly* converted to and from
    #    Hashes of their attributes.
    # So...this makes it all good. Except that Reek sees a
    # :reek:ControlParameter for `user`. Pffft.
    def user_from_param(user)
      User.new(user || repo.guest_user)
    end

    def update_attribs(new_password)
      new_hash = ::BCrypt::Password.create(new_password)
      { password_hash: new_hash, updated_at: Time.now }
    end

    def valid_password?(password)
      BCrypt::Password.new(user.password_hash) == password
    end

    def verify_preconditions(current_password)
      raise_logic_error :invalid_user if user.guest?
      raise_logic_error :bad_password unless valid_password?(current_password)
    end
  end
  # Leave the class visible during Gem development and testing; hide in an app
  private_constant :ChangePassword if Hanami.respond_to?(:env?)
end
