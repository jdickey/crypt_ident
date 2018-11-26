# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#change_password' do
  let(:attribs) do
    { name: 'J Random User', password: 'Old Clear-Text Password' }
  end
  let(:call_params) { [target_user, attribs[:password], new_password] }
  let(:new_password) { 'New Clear-Text Password' }
  let(:target_user) do
    saved_user = :unassigned
    sign_up(attribs, repo: repo, current_user: nil) do |result|
      result.success { |config:, user:| saved_user = user }
      result.failure { |code:, config:| next }
    end
    saved_user
  end

  describe 'Successfully change password using' do
    let(:result_from_success) do
      lambda do
        change_password(*call_params, repo: repo)  do |result|
          result.success { |user:| actual = user }
          result.failure { next }
        end
      end
    end

    before do
      dummy_repo = repo || CryptIdent.configure_crypt_ident.repository
      dummy_repo.clear
      _ = target_user
    end

    describe 'specified Repository' do
      let(:repo) { UserRepository.new }

      describe 'returns an Entity with' do
        describe 'changed attribute values for' do
          it ':password_hash' do
            old_hashed_pass = target_user.password_hash
            actual = result_from_success.call
            expect(old_hashed_pass).wont_equal actual.password_hash
          end

          it ':updated_at' do
            old_value = target_user.updated_at
            actual = result_from_success.call
            expect(actual.updated_at).must_be :>, old_value
          end
        end # describe 'changed attribute values for'

        it 'unchanged values for other attributes' do
          old_values = target_user.to_h.values_at(:id, :name, :created_at)
          actual = result_from_success.call
          new_values = actual.to_h.values_at(:id, :name, :created_at)
          expect(old_values).must_equal new_values
        end
      end # describe 'returns an Entity with'

      describe 'persists an Entity with' do
        it 'the same attributes as the returned Entity' do
          actual = result_from_success.call
          persisted_entity = repo.find(actual.id)
          expect(persisted_entity).must_equal actual
        end

        it 'an updated :hashed_pass attribute' do
          old_hashed_pass = target_user.password_hash
          actual = result_from_success.call
          new_hashed_pass = repo.find(actual.id).password_hash
          old_password = attribs[:password]
          expect(old_hashed_pass == old_password).must_equal true
          expect(new_hashed_pass == old_password).wont_equal true
          expect(new_hashed_pass == new_password).must_equal true
        end
      end # describe 'persists an Entity with'
    end # describe 'specified Repository'

    describe 'config-default Repository' do
      let(:repo) { nil }

      it 'correctly updates the Repository' do
        actual = result_from_success.call
        repo = CryptIdent.cryptid_config.repository
        updated = repo.find(target_user.id).password_hash
        expect(actual.password_hash.object_id).must_equal updated.object_id
      end
    end # describe 'config-default Repository'
  end # describe 'Successfully change password using'

  describe 'Fail to change password because the specified' do
    let(:repo) { CryptIdent.configure_crypt_ident.repository }
    let(:result_from_failure) do
      lambda do |user, current, new_password|
        change_password(user, current, new_password, repo: repo)  do |result|
          result.success { next }
          result.failure { |code:| actual = code }
        end
      end
    end

    describe '"user" Entity was invalid in this context' do
      it 'causes the method to report an error code of :invalid_user' do
        ret = result_from_failure.call(UserRepository.guest_user, 'password',
                                       'anything')
        expect(ret).must_equal :invalid_user
      end

      it 'does not affect the Repository' do
        before_call = repo.all
        ret = result_from_failure.call(nil, 'password', 'anything')
        expect(before_call).must_equal repo.all
      end
    end # describe '"user" Entity was invalid in this context'

    describe 'Clear-Text Password could not be Authenticated' do
      let(:user) { repo.first || target_user }

      it 'causes the method to return :bad_password' do
        ret = result_from_failure.call(user, 'bad password', 'anything')
        expect(ret).must_equal :bad_password
      end

      it 'does not affect the Repository' do
        before_call = repo.all
        result_from_failure.call(user, 'bad password', 'anything')
        expect(before_call).must_equal repo.all
      end
    end # describe 'Clear-Text Password could not be Authenticated'
  end # describe 'Fail to change password because the specified'
end
