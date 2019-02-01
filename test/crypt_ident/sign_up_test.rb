# frozen_string_literal: true

require 'test_helper'

describe 'CryptIdent#sign_up' do
  let(:existing) do
    attribs = valid_input_params
    password_hash = ::BCrypt::Password.create(attribs[:password])
    all_attribs = { password_hash: password_hash }.merge(valid_input_params)
    CryptIdent.config.repository.create(all_attribs)
  end
  let(:params) { { current_user: nil } }
  let(:user_name) { 'J Random User' }
  let(:valid_input_params) { { name: user_name } }

  after do
    CryptIdent.config.repository.clear
  end

  describe 'with no Authenticated Current User and a valid User Name' do
    it 'adds the new User Entity to the Repository' do
      actual_user = :unassigned
      actual_user = sign_up(valid_input_params, params) do |result|
        result.success { |user:| user }

        # *Must* define both `result.success` and `result.failure` blocks
        result.failure { fail 'Oops' }
      end
      repo = CryptIdent.config.repository
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal actual_user
    end

    it 'yields the expected parameters to the block' do
      saved = sign_up(valid_input_params, params) do |result|
        result.success do |user:|
          { user: user }
        end
        result.failure { fail 'Oops' }
      end
      expect(saved[:user]).must_equal CryptIdent.config.repository.last
    end

    it 'encrypts a random Password value, ignoring any specified value' do
      input_params = { password: 'password' }.merge(valid_input_params)
      saved_user = sign_up(input_params, params) do |result|
        result.success { |user:| user }
        result.failure { fail 'Oops' }
      end
      expect(saved_user.password_hash == 'password').must_equal false
    end

    it 'adds a :token value to the persisted Entity' do
      saved_user = sign_up(valid_input_params, params) do |result|
        result.success { |user:| user }
        result.failure { fail 'Oops' }
      end
      expect(saved_user.token.to_s).wont_be :empty?
    end

    it 'adds a :password_reset_expires_at timestamp to the persisted Entity' do
      saved_user = sign_up(valid_input_params, params) do |result|
        result.success { |user:| user }
        result.failure { fail 'Oops' }
      end
      actual = saved_user.password_reset_expires_at
      expect(actual).must_be :>, saved_user.updated_at
    end
  end # describe 'with no Authenticated Current User and a valid User Name'

  describe 'with an existing User having the same :name attribute' do
    before { _ = existing }

    it 'returns :user_already_created from the method' do
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success { raise 'Huh?' }

        result.failure { |code:| saved_code = code }
      end
      expect(saved_code).must_equal :user_already_created
    end

    it 'does not change the contents of the Repository' do
      all_before = CryptIdent.config.repository.all
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal all_before
    end
  end # describe 'with an existing User having the same :name attribute'

  describe 'with an Authenticated Current User' do
    let(:params) { { current_user: existing } }

    it 'returns :current_user_exists from the method' do
      valid_input_params[:name] = 'N Other User'
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success { raise 'Huh?' }

        result.failure { |code:| saved_code = code }
      end
      expect(saved_code).must_equal :current_user_exists
    end

    it 'does not change the contents of the Repository' do
      _ = existing
      all_before = CryptIdent.config.repository.all
      valid_input_params[:name] = 'N Other User'
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal all_before
    end
  end # describe 'with an Authenticated Current User'

  describe 'if the new User could not be created in the Repository' do
    before do
      @method = CryptIdent.config.repository.method(:create)
      CryptIdent.config.repository.define_singleton_method :create do |data|
        raise Hanami::Model::Error, 'Something broke. Oh, well.'
      end
    end

    after do
      CryptIdent.config.repository.define_singleton_method(:create, @method)
    end

    it 'returns :user_creation_failed from the method' do
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success { raise 'Huh?' }

        result.failure { |code:| saved_code = code }
      end
      expect(saved_code).must_equal :user_creation_failed
    end

    it 'does not change the contents of the Repository' do
      all_before = CryptIdent.config.repository.all
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(CryptIdent.config.repository.all).must_equal all_before
    end
  end # describe 'if the new User could not be created in the Repository'

  describe 'when no :repo parameter is specified' do
    it 'uses the :repository from the configuration object' do
      saved_user = :unassigned
      repo = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success do |user:|
          saved_user = user
        end

        result.failure { next }
      end
      repo = CryptIdent.config.repository
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal saved_user
    end
  end # describe 'when no :repo parameter is specified'
end
