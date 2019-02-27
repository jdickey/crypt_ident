# frozen_string_literal: true

# This is an integration test for CryptIdent that demonstrates what happens when
# a Password Reset Token expires before it is used to Reset a User's Password.
# A _successful_ Password Reset is demonstrated by other integration tests. The
# progression here is pretty straightforward:
#
# 1. Using Timecop to travel back in time, Register a New User and obtain the
#    Password Reset Token needed to set an initial password.
# 2. Back in the present, use that Token to attempt a Password Reset.
# 3. Verify that the Password Reset fails.

require 'support/minitest_helper'
require 'support/model_and_repo_classes'
require 'support/model_loader'

require 'timecop'

require 'crypt_ident'

include CryptIdent

describe 'Iterating the steps in the Password Reset (failure) workflow' do
  let(:email) { 'jrandom@example.com' }
  let(:user_name) { 'J Random User' }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }

  after do
    CryptIdent.config.repository.clear
  end

  it 'produces the expected failure' do
    two_years_ago = Time.now - (24 * 3600 * 365 * 2)
    the_user = :unassigned
    current = CryptIdent.config.guest_user.to_h
    Timecop.travel(two_years_ago) do
      # Register a New User
      sign_up_params = { name: user_name, profile: profile, email: email }
      CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
        result.success { |user:| the_user = user }
        result.failure { |code:| raise "Oops #{code}" } # shouldn't happen
      end
    end

    # Perform a Password Reset and verify that Token has expired. Use explicit
    # Guest User (as a Hash of attributes).

    CryptIdent.reset_password(the_user.token, password,
      current_user: CryptIdent.config.guest_user.to_h) do |result|
      result.success { raise 'Oops' } # shouldn't happen
      result.failure { |code:, token:| expect(code).must_equal :expired_token }
    end
  end
end
