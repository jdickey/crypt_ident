# frozen_string_literal: true

require 'test_helper'

require 'securerandom'

include CryptIdent

describe 'CryptIdent#reset_password' do
  let(:created_user) do
    password_hash = BCrypt::Password.create(password)
    user = User.new name: user_name, password_hash: password_hash,
                    token: token, password_reset_expires_at: expires_at
    our_repo = repo || CryptIdent.cryptid_config.repository
    our_repo.create(user)
  end
  let(:new_password) { 'New Sufficiently Entropic Passphrase' }
  let(:other_params) { { repo: repo, current_user: nil } }
  let(:password) { 'A Password' }
  let(:token) { SecureRandom.alphanumeric(24) }
  let(:user_name) { 'J Random Someone' }

  before do
    our_repo = repo || CryptIdent.cryptid_config.repository
    our_repo.clear
  end

  describe 'using an explicitly-supplied Repository' do
    let(:repo) { UserRepository.new }

    describe 'when supplied a valid token, a new password, no Current User' do
      let(:expires_at) { Time.now + 3600 }

      describe 'it passes a User Entity to the result.success block with' do
        it 'an updated :password_hash attribute' do
          old_password_hash = created_user.password_hash
          the_user = :unassigned # must be defined in scope to work with result
          reset_password(created_user.token, new_password,
                         other_params) do |result|
            result.success { |user:| the_user = user }
            result.failure { raise 'Oops' }
          end
          expect(the_user.password_hash).wont_equal old_password_hash
        end

        it 'a cleared :password_reset_expires_at attribute' do
          the_user = :unassigned
          reset_password(created_user.token, new_password,
                         other_params) do |result|
            result.success { |user:| the_user = user }
            result.failure { fail 'Oops' }
          end
          expect(the_user.password_reset_expires_at).must_be :nil?
        end

        it 'a cleared :token attribute' do
          the_user = :unassigned
          reset_password(created_user.token, new_password,
                         other_params) do |result|
            result.success { |user:| the_user = user }
            result.failure { fail 'Oops' }
          end
          expect(the_user.token).must_be :nil?
        end

        it 'an updated :updated_at attribute' do
          the_user = :unassigned
          old_updated_at = created_user.updated_at
          reset_password(created_user.token, new_password,
                         other_params) do |result|
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
          reset_password(token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| error_code = code }
          end
          expect(error_code).must_equal :expired_token
        end

        it 'a config: value containing a Repository with the User' do
          error_config = :unassigned
          _ = created_user
          reset_password(token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| error_config = config }
          end
          found = error_config.repository.find_by_name(created_user.name)
          expect(found.first).must_equal created_user
        end

        it 'a token: value with the supplied token value' do
          error_token = :unassigned
          _ = created_user
          reset_password(token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| error_token = token }
          end
          expect(error_token).must_equal token
        end
      end # describe 'it passes values to the result.failure block with'

      it 'does not update the Repository' do
        _ = created_user
        original = repo.all
        reset_password(token, new_password, other_params) do |result|
          result.success { fail 'Oops' }
          result.failure { next }
        end
        expect(repo.all).must_equal original
      end
    end # describe 'when supplied an expired token, new password, ...'

    describe 'when no User in the Repository matches the Token' do
      let(:bad_token) { SecureRandom.alphanumeric(24) }

      describe 'it passes values to the result.failure block with' do
        it 'a code: value of :token_not_found' do
          fail_code = :unassigned
          reset_password(bad_token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| fail_code = code }
          end
          expect(fail_code).must_equal :token_not_found
        end

        it 'a config: value containing a Repository with no matching token' do
          fail_config = :unassigned
          reset_password(bad_token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| fail_config = config }
          end
          repo = fail_config.repository
          expect(repo.find_by_token(token)).must_be :empty?
        end

        it 'a token: value with the supplied token value' do
          error_token = :unassigned
          reset_password(bad_token, new_password, other_params) do |result|
            result.success { raise 'Oops' }
            result.failure { |code:, config:, token:| error_token = token }
          end
          expect(error_token).must_equal bad_token
        end
      end # describe 'it passes values to the result.failure block with'

      it 'does not update the Repository' do
        original = repo.all
        reset_password(bad_token, new_password, other_params) do |result|
          result.success { raise 'Oops' }
          result.failure { next }
        end
        expect(repo.all).must_equal original
      end
    end # describe 'when no User in the Repository matches the Token'
  end # describe 'using an explicitly-supplied Repository'

  describe 'using the config-default Repository' do
    let(:repo) { nil }

    describe 'when supplied a valid token, a new password, no Current User' do
      let(:expires_at) { Time.now + 3600 }

      describe 'it passes a User Entity to the result.success block with' do
        it 'an updated :password_hash attribute' do
          old_password_hash = created_user.password_hash
          the_user = :unassigned # must be defined in scope to work with result
          reset_password(created_user.token, new_password,
                         other_params) do |result|
            result.success { |user:| the_user = user }
            result.failure { raise 'Oops' }
          end
          expect(the_user.password_hash).wont_equal old_password_hash
        end
      end # describe 'it passes a User Entity to the result.success block with'
    end # describe 'when ... a valid token, a new password, no Current User'
  end # describe 'using the config-default Repository'
end
