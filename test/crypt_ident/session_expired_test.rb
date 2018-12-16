# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#session_expired?' do
  let(:guest_user) { UserRepository.guest_user }
  let(:pwhash) { BCrypt::Password.create('password') }
  let(:session_data) { { current_user: user } }

  describe 'when the passed-in :current_user is' do
    describe 'a Registered User' do
      let(:user) { User.new(name: 'User 1', password_hash: pwhash, id: 27) }

      describe 'and when the passed-in :expires_at is' do
        it 'a future time' do
          session_data[:expires_at] = Time.now + 60 # seconds
          expect(session_expired?(session_data)).must_equal false
        end

        it 'the current time' do
          session_data[:expires_at] = Time.now
          expect(session_expired?(session_data)).must_equal true
        end

        it 'a past time' do
          session_data[:expires_at] = Time.now - 10 # seconds
          expect(session_expired?(session_data)).must_equal true
        end

        it 'nil' do
          expect(session_expired?(session_data)).must_equal true
        end
      end # describe 'and when the passed-in :expires_at is'
    end # describe 'a Registered User'

    describe 'the explicit Guest User' do
    end # describe 'the explicit Guest User'

    describe 'nil (the implicit Guest User)' do
    end # describe 'nil (the implicit Guest User)'
  end # describe 'when the passed-in :current_user is'
end
