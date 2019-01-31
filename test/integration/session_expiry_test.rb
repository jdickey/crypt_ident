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
# 5. The `session_data[:expires_at]` value is set to either *before* `Time.now`
#    (to test detecting Expiration) or *after* `Time.now` (to report that the
#    Session has not Expired).
# 6. The `CryptIdent#session_expired?` method is called and its return value
#    examined based on the expiration time as described in the previous step.
#
# ## Cleanup
#
# 7. The User is Signed Out and its Entity deleted.
# 8. The Repository is cleared and the Repository object deleted.
#
# For a further discussion of the rationale for these tests, see the commentary
# in `register_and_authenticate_test.rb` in this directory.

require 'support/minitest_helper'
require 'support/model_and_repo_classes'
require 'support/model_loader'

require 'crypt_ident'

include CryptIdent

describe 'Iterating the steps in the Change Password workflow' do
  let(:email) { 'jrandom@example.com' }
  let(:long_ago) { Time.now - (24 * 3600 * 365 * 100) }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }
  let(:user_name) { 'J Random User' }

  before do
    CryptIdent.config.repository = UserRepository.new
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
    CryptIdent.config.repository = nil
  end

  describe 'with no Authenticated User' do
    let(:session_data) { { expires_at: long_ago } }

    it 'does not Expire in a reasonable length of time' do
      expect(CryptIdent.session_expired?(session_data)).must_equal false
    end
  end # describe 'with no Authenticated User'

  describe 'with an Authenticated User and session data that should' do
    let(:session_data) { { current_user: @the_user } }

    describe 'not trigger Expiration' do
      it 'reports that the Session has not Expired' do
        # Time.now is five seconds before it would Expire the session
        session_data[:expires_at] = Time.now + 5
        expect(CryptIdent.session_expired?(session_data)).must_equal false
      end
    end # describe 'not trigger Expiration'

    describe 'trigger Expiration' do
      it 'reports an Expired Session' do
        # Time.now is five seconds *after* it would Expire the session
        session_data[:expires_at] = Time.now - 5
        expect(CryptIdent.session_expired?(session_data)).must_equal true
      end
    end
  end # describe 'with an Authenticated User and session data that should'
end
