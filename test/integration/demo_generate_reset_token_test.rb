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
#
# At this point, the User exists in the Repository. Consider a hypothetical
# client application's use case, where the User has Signed Up but somehow lost
# the original email (etc) with its included link to a URL which embeds the
# Password Reset Token. She would then use the app's UI to request a new
# Password Reset, which would invoke the `#generate_reset_token` method.
#
# ## Intentional Tests
#
# 3. Using the User Name specified earlier, and no Current User, call the
#    `#generate_reset_token` method, verifying a successful result with a User
#    Entity that:
#    a. has the same User Name;
#    b. has been persisted to the Repository;
#    c. has a future `:password_reset_expires_at` value and a `:token` value.
# 4. Using a different/random User Name, and no Current User, call the
#    method, verifying an unsueccessful result that:
#    a. has a `:code` value of `:user_not_found`
#    b. has the same User Name;
#    c. has a `:current_user` value of the Guest User.
# 5. Using the User Name specified earlier, and a Current User with a different
#    User Name, call the method, verifying an unsuccessful result that:
#    a. has a `:code` value of `:user_logged_in`;
#    b. has a `:name` value of `:unassigned`;
#    c. has a `:current_user` value of the specified Current User.
#
# ## Cleanup
#
# 6. The Repository is cleared.
#
# For a further discussion of the rationale for these tests, see the commentary
# in `register_and_authenticate_test.rb` in this directory.

require 'support/minitest_helper'
require 'support/model_and_repo_classes'
require 'support/model_loader'

require 'crypt_ident'

include CryptIdent

def set_up_user(name, email, profile = 'Profile')
  # Register a New User
  sign_up_params = { name: name, profile: profile, email: email }
  the_user = :unassigned
  CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
    result.success { |user:| the_user = user }
    result.failure { next } # shouldn't happen; real code *would* test
  end
  # Perform a Password Reset
  CryptIdent.reset_password(the_user.token, password) do |result|
    result.success { |user:| the_user = user } # password hash changed
    result.failure { next } # shouldn't happen; real code *would* test
  end
  the_user
end

describe 'with' do
  let(:email) { 'jrandom@example.com' }
  let(:long_ago) { Time.now - (24 * 3600 * 365 * 100) }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }
  let(:user_name) { 'J Random User' }

  before do
    @the_user = set_up_user(user_name, email, profile)
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

  describe 'a value for the Current User of' do
    describe 'the default nil and' do
      describe 'an existing User Name' do
        it 'succeeds' do
          the_user = :unassigned
          CryptIdent.generate_reset_token(user_name) do |result|
            result.success { |user:| the_user = user }
            result.failure { |code:, current_user:, name:|
              pp [:test_112, code, current_user, name, user_name]
              raise 'Oops'
            }
            # result.failure { raise 'Oops' }
          end
          expect(the_user.name).must_equal user_name
          expect(the_user.password_reset_expires_at).must_be :>, Time.now
          expect(the_user).must_equal CryptIdent.config.repository.last
        end
      end # describe 'an existing User Name'

      describe 'a nonexistent User Name' do
        it 'fails' do
          the_code = the_name = the_user = :unassigned
          bad_user_name = 'Some Other User'
          CryptIdent.generate_reset_token(bad_user_name) do |result|
            result.success { raise 'Oops' }
            result.failure do |code:, current_user:, name:|
              the_code = code
              the_name = name
              the_user = current_user
            end
          end
          expect(the_code).must_equal :user_not_found
          expect(the_name).must_equal bad_user_name
          expect(the_user).must_equal CryptIdent.config.guest_user
        end
      end # describe 'a nonexistent User Name'
    end # describe 'the default nil and'

    describe 'the Guest User and' do
      it 'an existing User Name succeeds' do
        the_user = :unassigned
        CryptIdent.generate_reset_token(user_name,
          current_user: CryptIdent.config.guest_user.to_h) do |result|
          result.success { |user:| the_user = user }
          result.failure do |code:, current_user:, name:|
            raise 'Oops'
          end
        end
        expect(the_user.name).must_equal user_name
        expect(the_user.password_reset_expires_at).must_be :>, Time.now
        expect(the_user).must_equal CryptIdent.config.repository.last
      end
    end # describe 'the Guest User and'

    describe 'an existing User Entity and' do
      it 'fails' do
        the_code = the_name = the_user = :unassigned
        xuser = set_up_user('Another User', 'other@example.com', 'profile')
        CryptIdent.generate_reset_token(user_name, current_user: xuser) do |res|
          res.success { raise 'Oops' }
          res.failure do |code:, current_user:, name:|
            the_code = code
            the_name = name
            the_user = current_user
          end
        end
        expect(the_code).must_equal :user_logged_in
        expect(the_name).must_equal :unassigned
        expect(the_user).must_equal xuser
      end
    end # describe 'an existing User Entity and'
  end # describe 'a value for the Current User of'
end # describe 'with'
