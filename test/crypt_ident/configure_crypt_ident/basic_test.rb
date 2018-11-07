# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent.configure_crypt_ident' do
  describe 'when called without a block, it' do
    describe 'returns object with default attributes, including' do
      let(:actual) { CryptIdent.configure_crypt_ident }

      it ':error_key' do
        expect(actual.error_key).must_equal :error
        expect(actual.to_h[:error_key]).must_equal actual.error_key
      end

      it ':guest_user' do
        expect(actual.guest_user).must_be_instance_of User
        expect(actual.to_h[:guest_user]).must_equal actual.guest_user
      end

      it ':hashing_cost' do
        expect(actual.hashing_cost).must_equal 8
        expect(actual.to_h[:hashing_cost]).must_equal actual.hashing_cost
      end

      it ':repository' do
        expect(actual.repository.class.relation).must_equal :user
        expect(actual.repository).must_respond_to :update
      end

      it ':reset_expiry' do
        expect(actual.reset_expiry).must_equal (24 * 60 * 60)
        expect(actual.to_h[:reset_expiry]).must_equal actual.reset_expiry
      end

      it 'session_expiry' do
        expect(actual.session_expiry).must_equal (15 * 60)
        expect(actual.to_h[:session_expiry]).must_equal actual.session_expiry
      end

      it ':success_key' do
        expect(actual.success_key).must_equal :success
        expect(actual.to_h[:success_key]).must_equal actual.success_key
      end

      it ':token_bytes' do
        expect(actual.token_bytes).must_equal 16
        expect(actual.to_h[:token_bytes]).must_equal actual.token_bytes
      end
    end # describe 'returns object with default attributes, including'
  end # describe 'when called without a block, it'
end
