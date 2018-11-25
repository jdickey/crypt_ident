# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#sign_up' do
  let(:existing) do
    attribs = valid_input_params
    password_hash = ::BCrypt::Password.create(attribs[:password])
    all_attribs = { password_hash: password_hash }.merge(valid_input_params)
    repo.create(all_attribs)
  end
  let(:params) { { repo: repo, current_user: nil } }
  let(:repo) { UserRepository.new }
  let(:valid_input_params) do
    { name: 'J Random User', password: 'Suitably Entropic Password!' }
  end

  before { CryptIdent.reset_crypt_ident_config }

  describe 'with no Authenticated Current User and valid attributes' do
    it 'adds the new User Entity to the Repository' do
      actual_user = :unassigned
      sign_up(valid_input_params, repo: repo, current_user: nil) do |result|
        result.success do |config:, user:|
          actual_user = user
        end

        # *Must* define both `result.success` and `result.failure` blocks
        result.failure { fail 'Oops' }
      end
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal actual_user
    end

    it 'yields the expected parameters to the block' do
      saved = sign_up(valid_input_params, params) do |result|
        result.success do |config:, user:|
          { conf: config, user: user }
        end

        result.failure { fail 'Oops' }
      end
      expect(saved[:conf]).must_equal CryptIdent.configure_crypt_ident
      expect(saved[:user]).must_equal repo.last
    end

    describe 'when a Password is specified' do
      it 'the User can Authenticate correctly' do
        saved_user = :unassigned
        sign_up(valid_input_params, params) do |result|
          result.success do |config:, user:|
            saved_user = user
          end

          result.failure { fail 'Oops' }
        end
        user_with_password = sign_in(saved_user, valid_input_params[:password])
        expect(user_with_password).wont_be :nil?
      end
    end # describe 'when a Password is specified'

    describe 'Encrypts a random Password value when input is' do
      let(:input_params) { valid_input_params }
      let(:save_user_on_success) do
        -> (result) do
          result.success do |config:, user:|
            saved_user = user
          end

          result.failure { fail 'Oops' }
        end
      end

      it 'not supplied, aka nil' do
        input_params.delete :password
        saved_user = :unassigned
        sign_up(input_params, params) do |result|
          result.success do |config:, user:|
            saved_user = user
          end

          result.failure { fail 'Oops' }
        end
        expect(saved_user.password_hash == nil).wont_equal true
      end

      it 'an empty string' do
        input_params[:password] = ''
        saved_user = :unassigned
        sign_up(input_params, params) do |result|
          saved_user = save_user_on_success.call(result)
        end
        expect(saved_user.password_hash == '').wont_equal true
      end

      it 'entirely made up of whitespace' do
        password = "\t\n\r   \r  \t \n"
        input_params[:password] = password
        saved_user = :unassigned
        sign_up(input_params, params) do |result|
          saved_user = save_user_on_success.call(result)
        end
        expect(saved_user.password_hash == password).wont_equal true
      end
    end # describe 'Encrypts a random Password value when input is'
  end # describe 'with no Authenticated Current User and valid attributes'

  describe 'with an existing User having the same :name attribute' do
    before { _ = existing }

    it 'returns :user_already_created from the method' do
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success { |config:, user:| raise 'Huh?' }

        result.failure { |config:, code:| saved_code = code }
      end
      expect(saved_code).must_equal :user_already_created
    end

    it 'does not change the contents of the Repository' do
      all_before = repo.all
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(repo.all).must_equal all_before
    end
  end # describe 'with an existing User having the same :name attribute'

  describe 'with an Authenticated Current User' do
    let(:params) { { repo: repo, current_user: existing } }

    it 'returns :current_user_exists from the method' do
      valid_input_params[:name] = 'N Other User'
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success { |config:, user:| raise 'Huh?' }

        result.failure { |config:, code:| saved_code = code }
      end
      expect(saved_code).must_equal :current_user_exists
    end

    it 'does not change the contents of the Repository' do
      _ = existing
      all_before = repo.all
      valid_input_params[:name] = 'N Other User'
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(repo.all).must_equal all_before
    end
  end # describe 'with an Authenticated Current User'

  describe 'if the new User could not be created in the Repository' do
    let(:acquire_code_from_failure) do
      -> (result) do
        result.success { |config:, user:| raise 'Huh?' }

        result.failure { |config:, code:| saved_code = code }
      end
    end

    before do
      repo.define_singleton_method :create do |data|
        raise Hanami::Model::Error, 'Something broke. Oh, well.'
      end
    end

    it 'returns :user_creation_failed from the method' do
      saved_code = :unassigned
      sign_up(valid_input_params, params) do |result|
        saved_code = acquire_code_from_failure.call(result)
      end
      expect(saved_code).must_equal :user_creation_failed
    end

    it 'does not change the contents of the Repository' do
      all_before = repo.all
      sign_up(valid_input_params, params) do |result|
        result.success { next }

        result.failure { next }
      end
      expect(repo.all).must_equal all_before
    end
  end # describe 'if the new User could not be created in the Repository'

  describe 'when no :repo parameter is specified' do
    it 'uses the :repository from the configuration object' do
      saved_user = :unassigned
      repo = :unassigned
      sign_up(valid_input_params, params) do |result|
        result.success do |config:, user:|
          saved_user = user
          repo = config.repository
        end

        result.failure { next }
      end
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal saved_user
    end
  end # describe 'when no :repo parameter is specified'
end
