# frozen_string_literal: true

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

  # Determine whether the Session has Expired due to User inactivity.
  #
  # This class *is not* part of the published API.
  # @private
  class SessionExpired
    def call(session_data)
      # Guest sessions never expire.
      return false if guest_user_from?(session_data)

      expiry_from(session_data) <= Time.now
    end

    private

    def guest_user_from?(session_data)
      user = session_data[:current_user] || UserRepository.guest_user
      # If the `session_data` in fact came from Rack session data, then any
      # objects (such as a `User` Entity) have been converted to JSON-compatible
      # types. Hanami Entities can be implicitly converted to and from Hashes of
      # their attributes, so this part's easy...
      User.new(user).guest?
    end

    def expiry_from(session_data)
      Hanami::Utils::Kernel.Time(session_data[:expires_at].to_i)
    end
  end
  # Leave the class visible durinig Gem development and testing; hide in an app
  private_constant :SessionExpired if Hanami.respond_to?(:env?)
end
