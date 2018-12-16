# frozen_string_literal: true

require 'test_helper'

include CryptIdent

# Note that these tests use `UserRepository` **only** to get a standard Entity
# for the Guest User; we're dealing exclusively with *session* data. There's no
# reason for the "current user" to actually be in a Repository somewhere in
# order for `#update_session_expiry` to work.
describe 'CryptIdent#update_session_expiry' do
  let(:allowable_test_slop) { 0.5 } # seconds
  let(:expiry) { 300 } # seconds
  let(:guest_user) { UserRepository.guest_user }
  let(:pwhash) { BCrypt::Password.create('password') }
  let(:seconds_per_year) { 365 * 24 * 3600 }
  let(:session_data) { { current_user: user } }

  before do
    CryptIdent.configure_crypt_ident { |conf| conf.session_expiry = expiry }
  end

  describe 'when the passed-in :current_user is' do
    describe 'a User Entity other than the Guest User' do
      let(:user) { User.new(name: 'User 1', password_hash: pwhash, id: 27) }

      it 'resets the :expires_at timestamp to the expected future time' do
        actual = update_session_expiry(session_data)
        delta = actual[:expires_at] - user.updated_at
        expect(delta).must_be_close_to(expiry, allowable_test_slop)
      end
    end # describe 'a User Entity other than the Guest User'

    describe 'the explicit Guest User' do
      let(:user) { guest_user }

      it 'resets the :expired_at timestamp to a far-future timestamp' do
        expected_min = Time.now + 100 * seconds_per_year - allowable_test_slop
        actual = update_session_expiry(session_data)
        expect(actual[:expires_at]).must_be :>=, expected_min
      end
    end # describe 'the explicit Guest User'

    describe 'nil (the implicit Guest User)' do
      let(:user) { nil }

      it 'resets the :expired_at timestamp to a far-future timestamp' do
        expected_min = Time.now + 100 * seconds_per_year - allowable_test_slop
        actual = update_session_expiry(session_data)
        expect(actual[:expires_at]).must_be :>=, expected_min
      end
    end
  end # describe 'when the passed-in :current_user is'
end
