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
# @version 0.1.0
module CryptIdent
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
      if guest_user?(session_data)
        session_data.merge(guest_data)
      else
        session_data.merge(updated_expiry)
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
      user.guest?
    end

    def updated_expiry
      { expires_at: Time.now + session_expiry }
    end
  end
end
