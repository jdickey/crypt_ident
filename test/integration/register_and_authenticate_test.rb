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
# 1. Register a New User. This generates a Token which a client app would send
#    to the new User via email, usually embedded within a URL that the User
#    would visit to confirm identity. For our purposes, we simply capture the
#    Token for use in the following step. The test verifies that this completes
#    successfully by inspecting the Result monad returned from `#sign_up`.
# 2. Use the Token from the first step to perform a Password Reset and set a
#    (new) Password for the User. We inspect the Result returned from
#    `#reset_password` to verify success; once verified, we continue to the next
#    step.
# 3. Using the newly-specified Password, Sign In the User. The test inspects
#    the return value from `#sign_in` to verify success. (Since management of
#    the `current_user` stored in session data is outside the scope of this Gem,
#    no additional means exists to verify the autnentication status of a User).
# 4. Sign Out the User. The test verifies that this is reported as successful by
#    the `#sign_out` method; see the earlier step for a discussion of why no
#    additional verification means is available.
# 5. Attempt to Register a new User using the same information as in the
#    previous step. The test verifies that this fails and that the `#sign_up`
#    method indicates that the User already exists.
#
# Again, why do this as opposed to simply trusting unit tests, or waiting until
# a "real app" can test them? We want to be able to test in an environment that
# is
#
# 1. Integrated: This and similar, associated tests are part of the CryptIdent
#    Gem source tree; they'll be maintained going forward as needed to exercise
#    any changes in the CryptIdent API;
# 2. Realistic: By not requiring 'test_helper.rb', we're not including the mock
#    Repository class; we're not including analysis tools like SimpleCov; and we
#    *shouldn't be* exercising any fancy auto-loading beyond what an actual user
#    of the `crypt_ident` Gem would. By doing so, we can eliminate false
#    negatives for failures encountered with the 0.1.*x* releases of this Gem;
# 3. Confidence-building: These tests *only* deal with the API-level interface
#    to CryptIdent, allowing us to reimplement internals when justified and
#    prove that code which had worked before will continue to. Similarly, these
#    tests will break if existing APIs are changed; this can be a valuable
#    resource for documenting changes required to client code to work with the
#    new version.

require 'support/minitest_helper'
require 'support/model_and_repo_classes'
require 'support/model_loader'

require 'crypt_ident'

include CryptIdent

describe 'Iterating the steps in the New User workflow' do
  let(:email) { 'jrandom@example.com' }
  let(:user_name) { 'J Random User' }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }

  before do
    CryptIdent.config.repository = UserRepository.new
  end

  after do
    CryptIdent.config.repository.clear
  end

  it 'succeeds along the normal path' do
    # Register a New User
    sign_up_params = { name: user_name, profile: profile, email: email }
    the_user = the_code = :unassigned
    CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
      result.success do |user:|
        the_user = user
      end
      result.failure do |code:|
        expect(code).must_equal :unassigned # will fail and report actual code
        the_code = code
      end
    end
    expect(the_code).must_equal :unassigned
    expect(the_user).wont_equal :unassigned

    # Perform a Password Reset

    the_token = the_user.token
    old_password_hash = the_user.password_hash
    the_user = :unassigned
    CryptIdent.reset_password(the_token, password) do |result|
      result.success do |user:|
        the_user = user
      end

      result.failure do |code:, config:, token:|
        expect(code).must_equal :unassigned # fail and report actual code
      end
    end
    expect(the_user.password_hash).wont_equal old_password_hash

    # Sign In

    signed_in_user = :unassigned
    CryptIdent.sign_in(the_user, password) do |result|
      result.success { |user:| signed_in_user = user }
      result.failure { |code:| expect(code).must_equal :unassigned }
    end
    expect(signed_in_user).must_equal the_user

    # Sign Out

    the_result = CryptIdent.sign_out(current_user: the_user) do |result|
      result.success { next }
      result.failure { expect(nil).wont_be :nil? } # Should *never* fire.
    end
    expect(the_result).must_be :nil?
  end
end
