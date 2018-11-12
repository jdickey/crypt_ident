# frozen_string_literal: true

require 'hanami/entity'

# Configuration info for CryptIdent.
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Configuration attributes for `CryptIdent`, with default values.
  #
  # See {file:README.md the project README} for details.
  # Reek thinks this class has :reek:TooManyConstants and that @attributes is a
  # :reek:InstanceVariableAssumption. Welcome to dry-rb and Hanami.
  class Config < Hanami::Entity
    # Flash index to use for error messages.
    ERROR_KEY = :error
    # Hashing cost for BCrypt.
    # @see https://github.com/codahale/bcrypt-ruby#cost-factors
    HASHING_COST = 8
    # Password-reset expiry in seconds; defaults to 24 hours.
    RESET_EXPIRY = 24 * 60 * 60
    # Authentication session expiry in seconds; defaults to 15 minutes.
    SESSION_EXPIRY = 15 * 60
    # Flash index to use for success-notification messages.
    SUCCESS_KEY = :success
    # Length, in bytes, of the number to be generated for the token.
    # Default is 16.
    # @see https://ruby-doc.org/stdlib/libdoc/securerandom/rdoc/Random/Formatter.html#method-i-urlsafe_base64
    TOKEN_BYTES = 16

    attributes do
      attribute :error_key, Types::Symbol.default(ERROR_KEY)
      attribute :hashing_cost, Types::Int.default(HASHING_COST)
      attribute :guest_user, (Types::Class.default { repository.guest_user })
      attribute :repository, (Types::Class.default { UserRepository.new })
      attribute :reset_expiry, Types::Int.default(RESET_EXPIRY)
      attribute :session_expiry, Types::Int.default(SESSION_EXPIRY)
      attribute :success_key, Types::Symbol.default(SUCCESS_KEY)
      attribute :token_bytes, Types::Int.default(TOKEN_BYTES)

      # This exists purely to simplify the :guest_user attribute definition, for
      # the sake of RuboCop. Pfffffft.
      def repository
        @attributes[:repository].evaluate
      end
    end
  end
end
