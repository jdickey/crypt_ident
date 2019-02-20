# frozen_string_literal: true

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
  #     if !session_expired?(session)
  #       updates = update_session_expiry(session)
  #       session[:expires_at] = updates[:expires_at]
  #       return
  #     end
  #
  #     # ... sign out and redirect appropriately ...
  #   end
  # @session_data
  #   `:current_user` **must** be a User Entity. `nil` is accepted to indicate
  #                   the Guest User
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
    UpdateSessionExpiry.new.call(session_data)
  end

  # Produce an updated Session Expiration timestamp, to support session
  # management and prevent prematurely Signing Out a User.
  #
  # This class *is not* part of the published API.
  # @private
  class UpdateSessionExpiry
    def initialize
      config = CryptIdent.config
      @guest_user = config.guest_user
      @session_expiry = config.session_expiry
    end

    def call(session_data = {})
      result_data = session_data.to_hash
      if guest_user?(session_data)
        result_data.merge(guest_data)
      else
        result_data.merge(updated_expiry)
      end
    end

    private

    attr_reader :guest_user, :session_expiry

    GUEST_YEARS = 100
    SECONDS_PER_YEAR = 31_536_000
    private_constant :GUEST_YEARS, :SECONDS_PER_YEAR

    def guest_data
      { expires_at: Time.now + GUEST_YEARS * SECONDS_PER_YEAR }
    end

    def guest_user?(session_data)
      user = session_data[:current_user] || guest_user
      # If the `session_data` in fact came from Rack session data, then any
      # objects (such as a `User` Entity) have been converted to JSON-compatible
      # types. Hanami Entities can be implicitly converted to and from Hashes of
      # their attributes, so this part's easy...
      User.new(user).guest?
    end

    def updated_expiry
      { expires_at: Time.now + session_expiry }
    end
  end
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :UpdateSessionExpiry if Hanami.respond_to?(:env?)
end
