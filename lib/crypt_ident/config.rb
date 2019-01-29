# frozen_string_literal: true

require 'hanami/entity'

# Configuration info for CryptIdent.
#
# @author Jeff Dickey
# @version 0.2.0
module CryptIdent
  # Configuration attributes for `CryptIdent`, with default values.
  #
  # See {file:README.md the project README} for details.
  #
  # Also see the important notes for the `:repository` setting. There is no
  # default assigned for `:guest_user`, but assigning a `:repository` will
  # assign a `:guest_user`.
  #
  extend Dry::Configurable

  # Flash index to use for error messages.
  setting :error_key, :error, reader: true
  setting :guest_user, reader: true
  # Hashing cost for BCrypt. Note that each 1-unit increase *doubles* the
  # processing time needed to encode/decode a password.
  # @see https://github.com/codahale/bcrypt-ruby#cost-factors
  setting :hashing_cost, 8, reader: true
  # Hanami Repository instance to use for accessing User data.
  # NOTE: This *does not* have a default. It is the responsibility of the client
  #   code to *always* assign this before use.
  # NOTE: Also, setting the repository causes the `.guest_user` value to be
  #   assigned. If anyone knows a better way to accomplish this, PRs welcome.
  setting(:repository, reader: true) do |value|
    config.guest_user = value.guest_user if value
    value
  end
  # Password-reset expiry in seconds; defaults to 24 hours.
  setting :reset_expiry, (24 * 60 * 60), reader: true
  # Authentication session expiry in seconds; defaults to 15 minutes.
  setting :session_expiry, (15 * 60), reader: true
  # Flash index to use for success-notification messages.
  setting :success_key, :success, reader: true
  # Length, in bytes, of the number to be generated for the token. Default is
  # 24. (Must be a multiple of 12 to avoid padding when encoding using
  # `Base64.strict_encode64`.)
  # @see https://ruby-doc.org/stdlib/libdoc/securerandom/rdoc/Random/Formatter.html#method-i-urlsafe_base64
  setting :token_bytes, 24, reader: true
end
