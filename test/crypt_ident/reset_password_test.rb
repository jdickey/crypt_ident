# frozen_string_literal: true

require 'test_helper'

require 'securerandom'

describe 'CryptIdent#reset_password' do
  let(:created_user) do
    password_hash = BCrypt::Password.create(password)
    attribs = { name: user_name, password_hash: password_hash, token: token,
                password_reset_expires_at: expires_at }
    CryptIdent.config.repository.create(attribs)
  end
  let(:expires_at) { Time.now + 3600 }
  let(:new_password) { 'New Sufficiently Entropic Passphrase' }
  let(:password) { 'A Password' }
  let(:token) { SecureRandom.alphanumeric(24) }
  let(:user_name) { 'J Random Someone' }

  before do
    CryptIdent.config.repository.clear
    _ = created_user
  end

  after do
    CryptIdent.config.repository.clear
  end

  describe 'when supplied a valid token, a new password, no Current User' do
    describe 'it passes a User Entity to the result.success block with' do
      it 'an updated :password_hash attribute' do
        old_password_hash = created_user.password_hash
        the_user = :unassigned # must be defined in scope to work with result
        reset_password(created_user.token, new_password,
                       current_user: nil) do |result|
          result.success { |user:| the_user = user }
          result.failure { raise 'Oops' }
        end
        expect(the_user.password_hash).wont_equal old_password_hash
      end

      it 'a cleared :password_reset_expires_at attribute' do
        the_user = :unassigned
        reset_password(created_user.token, new_password,
                       current_user: nil) do |result|
          result.success { |user:| the_user = user }
          result.failure { fail 'Oops' }
        end
        expect(the_user.password_reset_expires_at).must_be :nil?
      end

      it 'a cleared :token attribute' do
        the_user = :unassigned
        reset_password(created_user.token, new_password,
                       current_user: nil) do |result|
          result.success { |user:| the_user = user }
          result.failure { fail 'Oops' }
        end
        expect(the_user.token).must_be :nil?
      end

      it 'an updated :updated_at attribute' do
        the_user = :unassigned
        old_updated_at = created_user.updated_at
        reset_password(created_user.token, new_password,
                       current_user: nil) do |result|
          result.success { |user:| the_user = user }
          result.failure { fail 'Oops' }
        end
        expect(the_user.updated_at).must_be :>, old_updated_at
      end
    end # describe 'it passes a User Entity to the result.success block with'
  end # describe 'when supplied valid token, a new password, no Current User'

  describe 'when supplied an expired token, new password, no Current User' do
    let(:expires_at) { Time.now - 3600 } # Expired an hour ago

    describe 'it passes values to the result.failure block with' do
      it 'a code: value of :expired_token' do
        error_code = :unassigned
        _ = created_user
        reset_password(token, new_password, current_user: nil) do |result|
          result.success { raise 'Oops' }
          result.failure { |code:, token:| error_code = code }
        end
        expect(error_code).must_equal :expired_token
      end

      it 'a token: value with the supplied token value' do
        error_token = :unassigned
        _ = created_user
        reset_password(token, new_password, current_user: nil) do |result|
          result.success { raise 'Oops' }
          result.failure { |code:, token:| error_token = token }
        end
        expect(error_token).must_equal token
      end
    end # describe 'it passes values to the result.failure block with'

    it 'does not update the Repository' do
      _ = created_user
      original = CryptIdent.config.repository.all
      reset_password(token, new_password, current_user: nil) do |result|
        result.success { fail 'Oops' }
        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal original
    end
  end # describe 'when supplied an expired token, new password, ...'

  describe 'when no User in the Repository matches the Token' do
    let(:bad_token) { SecureRandom.alphanumeric(24) }

    describe 'it passes values to the result.failure block with' do
      it 'a code: value of :token_not_found' do
        fail_code = :unassigned
        reset_password(bad_token, new_password, current_user: nil) do |result|
          result.success { raise 'Oops' }
          result.failure { |code:, token:| fail_code = code }
        end
        expect(fail_code).must_equal :token_not_found
      end

      it 'a token: value with the supplied token value' do
        error_token = :unassigned
        reset_password(bad_token, new_password, current_user: nil) do |result|
          result.success { raise 'Oops' }
          result.failure { |code:, token:| error_token = token }
        end
        expect(error_token).must_equal bad_token
      end
    end # describe 'it passes values to the result.failure block with'

    it 'does not update the Repository' do
      original = CryptIdent.config.repository.all
      reset_password(bad_token, new_password, current_user: nil) do |result|
        result.success { raise 'Oops' }
        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal original
    end
  end # describe 'when no User in the Repository matches the Token'

  describe 'when supplied a Current User (and thus an Authenticated User)' do
    let(:current_user) do
      password_hash = BCrypt::Password.create('Anything At All')
      token = SecureRandom.alphanumeric(24)
      attribs = { name: 'Someone Else', password_hash: password_hash,
                  token: token, password_reset_expires_at: expires_at }
      CryptIdent.config.repository.create(attribs)
    end

    describe 'it passes values to the result.failure block with' do
      it 'a code: value of :invalid_current_user' do
        fail_code = :unassigned
        reset_password(token, new_password,
                       current_user: current_user) do |result|
          result.success { raise 'Oops' }
          result.failure { |code:, token:| fail_code = code }
        end
        expect(fail_code).must_equal :invalid_current_user
      end
    end # describe 'it passes values to the result.failure block with'

    it 'does not update the Repository' do
      _ = current_user # make sure it's added to the Repository
      original = CryptIdent.config.repository.all
      reset_password(token, new_password,
                     current_user: current_user) do |result|
        result.success { raise 'Oops' }
        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal original
    end
  end # describe 'when supplied a Current User (...an Authenticated User)'
end
