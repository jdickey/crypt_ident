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
      user = sign_up(valid_input_params, repo: repo, current_user: nil)
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal user
    end

    it 'yields the expected parameters to the block' do
      saved = {}
      ret_user = sign_up(valid_input_params, params) do |user, conf|
        saved = { conf: conf, user: user }
      end
      expect(saved[:conf]).must_equal CryptIdent.configure_crypt_ident
      expect(saved[:user]).must_equal ret_user
    end

    describe 'when a Password is specified' do
      it 'the User can Authenticate correctly' do
        user = sign_up(valid_input_params, params)
        # FIXME: Rewrite using #sign_in when working
        actual = user.password_hash == valid_input_params[:password]
        expect(actual).must_equal true
      end
    end # describe 'when a Password is specified'

    describe 'Encrypts a random Password value when input is' do
      let(:input_params) { valid_input_params }

      it 'not supplied, aka nil' do
        input_params.delete :password
        user = sign_up(input_params, params)
        actual = user.password_hash == nil
        expect(actual).wont_equal true
      end

      it 'an empty string' do
        input_params[:password] = ''
        user = sign_up(input_params, params)
        actual = user.password_hash == ''
        expect(actual).wont_equal true
      end

      it 'entirely made up of whitespace' do
        password = "\t\n\r   \r  \t \n"
        input_params[:password] = password
        user = sign_up(input_params, params)
        actual = user.password_hash == password
        expect(actual).wont_equal true
      end
    end # describe 'Encrypts a random Password value when input is'
  end # describe 'with no Authenticated Current User and valid attributes'

  describe 'with an existing User having the same :name attribute' do
    before { _ = existing }

    it 'returns :user_already_created from the method' do
      ret = sign_up(valid_input_params, params)
      expect(ret).must_equal :user_already_created
    end

    it 'does not call the block supplied to the method' do
      # :nocov:
      sign_up(valid_input_params, params) do |_, _|
        fail 'Block should not be called'
      end
      # :nocov:
    end

    it 'does not change the contents of the Repository' do
      count = repo.all.count
      sign_up(valid_input_params, params)
      expect(repo.all.count).must_equal count
    end
  end # describe 'with an existing User having the same :name attribute'

  describe 'with an Authenticated Current User' do
    let(:params) { { repo: repo, current_user: existing } }

    it 'returns :current_user_exists from the method' do
      valid_input_params[:name] = 'N Other User'
      actual = sign_up(valid_input_params, params)
      expect(actual).must_equal :current_user_exists
    end

    it 'does not call the block supplied to the method' do
      valid_input_params[:name] = 'N Other User'
      block_called = false
      # :nocov:
      actual = sign_up(valid_input_params, params) do |_, _|
        block_called = true
      end
      # :nocov:
      expect(block_called).must_equal false
    end

    it 'does not change the contents of the Repository' do
      _ = existing
      count = repo.all.count
      valid_input_params[:name] = 'N Other User'
      sign_up(valid_input_params, params)
      expect(repo.all.count).must_equal count
    end
  end # describe 'with an Authenticated Current User'

  describe 'if the new User could not be created in the Repository' do
    let(:actual) { sign_up(valid_input_params, params) }

    before do
      repo.define_singleton_method :create do |data|
        raise Hanami::Model::Error, 'Something broke. Oh, well.'
      end
    end

    it 'returns :user_creation_failed from the method' do
      expect(actual).must_equal :user_creation_failed
    end

    it 'does not call the block supplied to the method' do
      block_called = false
      # :nocov:
      sign_up(valid_input_params, params) do |_, _|
        block_called = true
      end
      # :nocov:
      expect(block_called).must_equal false
    end

    it 'does not change the contents of the Repository' do
      sign_up(valid_input_params, params)
      expect(repo.all.count).must_be :zero?
    end
  end # describe 'if the new User could not be created in the Repository'

  describe 'when no :repo parameter is specified' do
    it 'uses the :repository from the configuration object' do
      user = sign_up(valid_input_params, current_user: nil)
      repo = CryptIdent.configure_crypt_ident.repository
      expect(repo.all.count).must_equal 1
      expect(repo.last).must_equal user
    end
  end # describe 'when no :repo parameter is specified'

  describe 'when an :on_error handler is specified' do
    it 'and no error is encountered' do
      proc_called = false
      on_error = Proc.new { |_error, _config| proc_called = true }
      user = sign_up(valid_input_params, current_user: nil, on_error: on_error)
      expect(proc_called).must_equal false
    end

    it 'and an error is encountered' do
      _ = existing
      proc_called = false
      on_error = Proc.new { |_error, _config| proc_called = true }
      params = { current_user: nil, on_error: on_error, repo: repo }
      user = sign_up(valid_input_params, params)
      expect(proc_called).must_equal true
    end
  end # describe 'when an :on_error handler is specified'
end
