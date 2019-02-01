# frozen_string_literal: true

require 'test_helper'

describe 'CryptIdent#change_password' do
  let(:call_params) { [target_user, original_password, new_password] }
  let(:new_password) { 'New Clear-Text Password' }
  let(:original_password) { 'Old Clear-Text Password' }
  let(:target_user) do
    password_hash = BCrypt::Password.create(original_password)
    attribs = { name: user_name, password_hash: password_hash }
    CryptIdent.config.repository.create(attribs)
  end
  let(:user_name) { 'J Random User' }

  before do
    CryptIdent.config.repository.clear
    _ = target_user
  end

  after do
    CryptIdent.config.repository.clear
  end

  describe 'Successfully change password and' do
    let(:result_from_success) do
      lambda do
        change_password(*call_params) do |result|
          result.success { |user:| actual = user }
          result.failure { next }
        end
      end
    end

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
        persisted_entity = CryptIdent.config.repository.find(actual.id)
        expect(persisted_entity).must_equal actual
      end

      it 'an updated :hashed_pass attribute' do
        old_hashed_pass = target_user.password_hash
        actual = result_from_success.call
        repo = CryptIdent.config.repository
        new_hashed_pass = repo.find(actual.id).password_hash
        expect(old_hashed_pass == original_password).must_equal true
        expect(new_hashed_pass == original_password).wont_equal true
        expect(new_hashed_pass == new_password).must_equal true
      end
    end # describe 'persists an Entity with'
  end # describe 'Successfully change password and'

  describe 'Fail to change password because the specified' do
    let(:result_from_failure) do
      lambda do |user, current, new_password|
        change_password(user, current, new_password) do |result|
          result.success { next }
          result.failure { |code:| actual = code }
        end
      end
    end

    describe '"user" Entity was invalid in this context' do
      it 'causes the method to report an error code of :invalid_user' do
        ret = result_from_failure.call(CryptIdent.config.guest_user, 'password',
                                       'anything')
        expect(ret).must_equal :invalid_user
      end

      it 'does not affect the Repository' do
        before_call = CryptIdent.config.repository.all
        ret = result_from_failure.call(nil, 'password', 'anything')
        expect(before_call).must_equal CryptIdent.config.repository.all
      end
    end # describe '"user" Entity was invalid in this context'

    describe 'Clear-Text Password could not be Authenticated' do
      let(:user) { CryptIdent.config.repository.first }

      it 'causes the method to return :bad_password' do
        ret = result_from_failure.call(user, 'bad password', 'anything')
        expect(ret).must_equal :bad_password
      end

      it 'does not affect the Repository' do
        _ = user
        before_call = CryptIdent.config.repository.all
        result_from_failure.call(user, 'bad password', 'anything')
        expect(before_call).must_equal CryptIdent.config.repository.all
      end
    end # describe 'Clear-Text Password could not be Authenticated'
  end # describe 'Fail to change password because the specified'
end
