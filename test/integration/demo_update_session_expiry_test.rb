# frozen_string_literal: true

# This is an integration test for CryptIdent. Integration tests differ from
# unit tests in that they're more use-case oriented; rather than iteratively
# testing every feature and error handler of a module or class, they demonstrate
# a sequence illustrating how the code would be used to "tell an end-to-end
# story". Development-only tools such as test coverage analysis, or mocks of
# framework classes, aren't used.
#
# This test exercises the following sequence of actions:
#
# ## Setup Steps
#
# 1. Register a New User, capturing the Token for use in the following step. The
#    test *does not* otherwise inspect or verify the Result; that is done by
#    other integration tests.
# 2. Use the Token from the first step to perform a Password Reset and set a
#    (new) Password for the User. Again, we perform no specific inspection here.
# 3. Using the newly-specified Password, Sign In the User.
# 4. The `session_data[:current_user]` value is set to the newly-Registered and
#    Signed In User.
#
# ## Intentional Tests
#
# 5. The `session_data[:expires_at]` value is set to a value *before* `Time.now`
#    and `CryptIdent#session_expired?` is called to demonstrate that that is
#    detected.
# 6. The `CryptIdent#update_session_expiry` method is called, and the value for
#    `session_data[:expires_at]` updated from its return value.
# 7. The `CryptIdent#session_expired?` method is called again, to demonstrate
#    that the Session has not Expired.
#
# ## Cleanup
#
# 8. The User is Signed Out and its Entity deleted.
# 9. The Repository is cleared.
#
# For a further discussion of the rationale for these tests, see the commentary
# in `register_and_authenticate_test.rb` in this directory.

require 'support/minitest_helper'
require 'support/model_and_repo_classes'
require 'support/model_loader'

require 'crypt_ident'

include CryptIdent

describe 'Demonstrating the CryptIdent#update_session_expiry method' do
  let(:email) { 'jrandom@example.com' }
  let(:long_ago) { Time.now - (24 * 3600 * 365 * 100) }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }
  let(:user_name) { 'J Random User' }

  before do
    # Register a New User
    sign_up_params = { name: user_name, profile: profile, email: email }
    @the_user = :unassigned
    CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
      result.success { |user:| @the_user = user }
      result.failure { next } # shouldn't happen; real code *would* test
    end
    # Perform a Password Reset
    CryptIdent.reset_password(@the_user.token, password) do |result|
      result.success { |user:| @the_user = user } # password hash changed
      result.failure { next } # shouldn't happen; real code *would* test
    end
    # Sign In
    CryptIdent.sign_in(@the_user, password) do |result|
      result.success { |user:| @the_user = user }
      result.failure { next } # shouldn't happen; real code *would* test
    end
  end

  after do
    # Sign Out
    CryptIdent.sign_out(current_user: @the_user) do |result|
      result.success { next }
      result.failure { next } # shouldn't happen
    end
    @the_user = nil
    CryptIdent.config.repository.clear
  end

  describe 'with an Authenticated User' do
    it 'proceeds as expected' do
      session_data = { current_user: @the_user.to_h, expires_at: long_ago }
      expect(CryptIdent.session_expired?(session_data)).must_equal true
      updates = CryptIdent.update_session_expiry(session_data)
      session_data[:expires_at] = updates[:expires_at]
      expect(CryptIdent.session_expired?(session_data)).must_equal false
    end
  end # describe 'with an Authenticated User'

  describe 'with the Guest User' do
    it 'proceeds as expected' do
      session_data = {}
      expect(CryptIdent.session_expired?(session_data)).must_equal false
      updates = CryptIdent.update_session_expiry(session_data)
      expect(updates[:expires_at]).must_be :>, Time.now
      session_data[:expires_at] = updates[:expires_at]
      expect(CryptIdent.session_expired?(session_data)).must_equal false
    end
  end
end
