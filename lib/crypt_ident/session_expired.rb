# frozen_string_literal: true

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
      user.guest?
    end

    def expiry_from(session_data)
      Hanami::Utils::Kernel.Time(session_data[:expires_at].to_i)
    end
  end
end
