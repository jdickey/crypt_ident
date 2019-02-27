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
#
# ## Intentional Tests
#
# 4. The `#change_password` method is called for the newly-Authenticated User.
#    Remember that the difference between the `#change_password` method and the
#    `#reset_password`method is that the former **must** be performed by an
#    Authenticated User; the latter **must not** be. The result is inspected to
#    verify success.
# 5. Sign Out the User.
# 6. Using the newly-specified Password, Sign In the User. The test inspects
#    the return value from `#sign_in` to verify success.
#
# ## Cleanup
#
# 7. The User is Signed Out.
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
  let(:new_password) { 'Another Suitably Entropic Multiple-Word Phrase' }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }
  let(:user_name) { 'J Random User' }

  after do
    CryptIdent.config.repository.clear
  end

  it 'succeeds along the normal path' do
    # Register a New User
    sign_up_params = { name: user_name, profile: profile, email: email }
    the_user = :unassigned
    CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
      result.success { |user:| the_user = user }
      result.failure { next } # shouldn't happen
    end

    # Perform a Password Reset

    CryptIdent.reset_password(the_user.token, password) do |result|
      result.success { |user:| the_user = user } # password hash changed
      result.failure { raise 'Oops' } # shouldn't happen
    end

    # Sign In

    CryptIdent.sign_in(the_user, password) do |result|
      result.success { |user:| the_user = user }
      result.failure { next } # shouldn't happen
    end

    # Change the User's Password

    CryptIdent.change_password(the_user, password, new_password) do |result|
      result.success { |user:| the_user = user } # password hash changed
      # Failure expectation will fail and report what the actual error code is.
      result.failure { |code:| expect(code).must_equal :unassigned }
    end

    # Sign Out (from Authentication using original Password)

    CryptIdent.sign_out(current_user: the_user) do |result|
      result.success { next }
      result.failure { next } # shouldn't happen
    end

    # ACID TEST TIME: Sign In using New Password.

    CryptIdent.sign_in(the_user, new_password) do |result|
      result.success { next } # user entity hasn't changed
      # Failure expectation will fail and report what the actual error code is.
      result.failure { |code:| expect(code).must_equal :unassigned }
    end

    # If we get this far, we Signed In successfully with the New Password. Done.

    CryptIdent.sign_out(current_user: the_user) do |result|
      result.success { next }
      result.failure { next } # shouldn't happen
    end
  end
end
