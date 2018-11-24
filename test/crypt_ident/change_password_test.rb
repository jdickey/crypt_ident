# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#change_password' do
  let(:attribs) do
    { name: 'J Random User', password: 'Old Clear-Text Password' }
  end
  let(:new_password) { 'New Clear-Text Password' }
  let(:repo) { UserRepository.new }

  describe 'Successfully change password using' do
    before { _ = user }

    describe 'specified Repository' do
      let(:actual) do
        change_password(user, attribs[:password], new_password, repo: repo)
      end
      let(:user) { sign_up(attribs, repo: repo, current_user: nil) }

      describe 'returns an Entity with' do
        describe 'changed attribute values for' do
          it ':password_hash' do
            old_hashed_pass = user.password_hash
            new_hashed_pass = actual.password_hash
            expect(old_hashed_pass).wont_equal new_hashed_pass
          end

          it ':updated_at' do
            old_value = user.updated_at
            new_value = actual.updated_at
            expect(new_value).must_be :>, old_value
          end
        end # describe 'changed attribute values for'

        it 'unchanged values for other attributes' do
          old_values = user.to_h.values_at(:id, :name, :created_at)
          new_values = actual.to_h.values_at(:id, :name, :created_at)
          expect(old_values).must_equal new_values
        end
      end # describe 'returns an Entity with'

      describe 'persists an Entity with' do
        it 'the same attributes as the returned Entity' do
          persisted_entity = repo.find(actual.id)
          expect(persisted_entity).must_equal actual
        end

        it 'an updated :hashed_pass attribute' do
          old_hashed_pass = user.password_hash
          new_hashed_pass = repo.find(actual.id).password_hash
          old_password = attribs[:password]
          expect(old_hashed_pass == old_password).must_equal true
          expect(new_hashed_pass == old_password).wont_equal true
          expect(new_hashed_pass == new_password).must_equal true
        end
      end # describe 'persists an Entity with'
    end # describe 'specified Repository'

    describe 'config-default Repository' do
      let(:actual) do
        change_password(user, attribs[:password], new_password)
      end
      let(:user) { sign_up(attribs, current_user: nil) }

      it 'correctly updates the Repository' do
        actual_password_hash = actual.password_hash
        repo = CryptIdent.cryptid_config.repository
        updated = repo.find(user.id).password_hash
        expect(actual_password_hash.object_id).must_equal updated.object_id
      end
    end # describe 'config-default Repository'
  end # describe 'Successfully change password using'

  describe 'Fail to change password because the specified' do
    describe '"user" Entity was invalid in this context' do
      it 'causes the method to return :invalid_user' do
        ret = change_password(UserRepository.guest_user, 'password', 'anything')
        expect(ret).must_equal :invalid_user
      end

      it 'does not affect the Repository' do
        before_call = repo.all
        change_password(nil, 'password', 'noo password', repo: repo)
        expect(before_call).must_equal repo.all
      end
    end # describe '"user" Entity was invalid in this context'

    describe 'Clear-Text Password could not be Authenticated' do
      let(:user) { sign_up(attribs, repo: repo, current_user: nil) }

      before { _ = user }

      it 'causes the method to return :bad_password' do
        ret = change_password(user, 'bad password', 'anything', repo: repo)
        expect(ret).must_equal :bad_password
      end

      it 'does not affect the Repository' do
        before_call = repo.all
        change_password(user, 'bad password', 'anything', repo: repo)
        expect(before_call).must_equal repo.all
      end
    end # describe 'Clear-Text Password could not be Authenticated'
  end # describe 'Fail to change password because the specified'
end
