# frozen_string_literal: true

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
  # Sign out a previously Authenticated User.
  #
  # The method *requires* a block, to which a `result` indicating success or
  # failure is yielded. (Presently, any call to `#sign_out` results in success.)
  # That block **must** in turn call **both** `result.success` and
  # `result.failure` (even though no failure is implemented) to handle success
  # and failure results, respectively. On success, the block yielded to by
  # `result.success` is called without parameters.
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
  #               ignored.
  # @yieldreturn [void]
  #
  # @example Controller Action Class method example resetting values
  #   def call(_params)
  #     sign_out(session[:current_user]) do |result|
  #       result.success do
  #         session[:current_user] = CryptIdent.config.guest_user
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
  #       result.success do
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

  # Sign-out logic for `CryptIdent`, per Issue #9.
  #
  # This class *is not* part of the published API.
  # @private
  class SignOut
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    # This method exists, despite YAGNI, to provide for future expansion of
    # features like analytics. More importantly, it provides an API congruent
    # with that of the (reworked) `#sign_up` and `#sign_in` methods.
    def call(current_user:)
      _ = current_user # presently ignored
      Success()
    end
  end
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :SignOut if Hanami.respond_to?(:env?)
end
