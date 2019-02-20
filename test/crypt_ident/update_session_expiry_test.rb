# frozen_string_literal: true

require 'test_helper'

describe 'CryptIdent#update_session_expiry' do
  let(:allowable_test_slop) { 0.5 } # seconds
  let(:expiry) { 300 } # seconds
  let(:pwhash) { BCrypt::Password.create('password') }
  let(:seconds_per_year) { 365 * 24 * 3600 }
  let(:session_data) { { current_user: user } }

  before do
    @old_expiry = CryptIdent.config.session_expiry
    CryptIdent.config.repository.clear
    CryptIdent.config.session_expiry = expiry
  end

  after do
    CryptIdent.config.repository.clear
    CryptIdent.config.session_expiry = @old_expiry
  end

  describe 'when the passed-in :current_user is' do
    describe 'a User Entity other than the Guest User' do
      let(:user) do
        entitycls = CryptIdent.config.repository.entity
        entitycls.new(name: 'User 1', password_hash: pwhash, id: 27)
      end

      it 'resets the :expires_at timestamp to the expected future time' do
        actual = update_session_expiry(session_data)
        delta = actual[:expires_at] - user.updated_at
        expect(delta).must_be_close_to(expiry, allowable_test_slop)
      end
    end # describe 'a User Entity other than the Guest User'

    describe 'the explicit Guest User' do
      let(:user) { CryptIdent.config.guest_user }

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

  describe 'when the session data' do
    it 'supports only a subset of standard Hash methods (Issue #28)' do
      entitycls = CryptIdent.config.repository.entity
      user = entitycls.new(name: 'User 1', password_hash: pwhash, id: 27)
      session_data = Object.new
      session_data.instance_variable_set(:@data, { current_user: user });
      session_data.define_singleton_method(:[]) do |key|
        @data[key]
      end
      session_data.define_singleton_method(:to_hash) do
        @data.to_hash.dup
      end

      expected_min = Time.now + CryptIdent.config.session_expiry
      actual = update_session_expiry(session_data)
      expect(actual[:expires_at]).must_be :>=, expected_min
    end
  end # describe 'when the session data'
end
