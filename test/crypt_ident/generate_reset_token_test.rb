# frozen_string_literal: true

require 'test_helper'

describe 'CryptIdent#generate_reset_token' do
  let(:created_user) do
    password_hash = BCrypt::Password.create(password)
    CryptIdent.config.repository.create(name: user_name,
                                        password_hash: password_hash)
  end
  let(:other_params) { { current_user: nil } }
  let(:password) { 'A Password' }
  let(:result_from_failure) do
    lambda do |user_name, current_user|
      the_code = the_current_user = the_name = :unassigned
      other_params = { current_user: current_user }
      generate_reset_token(user_name, other_params) do |result|
        result.success { next }
        result.failure do |code:, current_user:, name:|
          the_code = code
          the_current_user = current_user
          the_name = name
        end
      end
      { code: the_code, current_user: the_current_user, name: the_name }
    end
  end
  let(:result_from_success) do
    lambda do
      the_user = :unassigned
      generate_reset_token(user_name, other_params) do |result|
        result.success { |user:| the_user = user }
        result.failure { next }
      end
      the_user
    end
  end
  let(:user_name) { 'J Random Someone' }

  before do
    CryptIdent.config.repository.clear
  end

  after do
    CryptIdent.config.repository.clear
  end

  describe 'when supplied a valid User Name and a Current User of' do
    describe 'the default, nil' do
      describe 'it passes a User Entity to the result.success block with' do
        let(:actual) { created_user }

        before { _ = actual }

        it 'a valid :token attribute' do
          expect(actual.token).must_be :nil?
          actual = result_from_success.call
          token = :unassigned
          # will raise ArgumentError on invalid Base64 input
          token = Base64.strict_decode64(actual.token)
          expect(token).wont_equal :unassigned
        end

        it 'a valid :password_reset_expires_at attribute' do
          expect(actual.password_reset_expires_at).must_be :nil?
          actual = result_from_success.call
          remaining = actual.password_reset_expires_at - Time.now
          reset_expiry = CryptIdent.config.reset_expiry
          expect(reset_expiry - remaining).must_be :<, 5 # seconds
        end
      end # describe 'it passes a User Entity to the result.success block with'

      it 'persists the updated Entity to the Repository' do
        _ = created_user
        entity = result_from_success.call
        repo = CryptIdent.config.repository
        expect(repo.first).must_equal entity
        expect(repo.all.count).must_equal 1
      end

      describe 'overwrites any previously-persisted attribute values for' do
        before do
          _ = created_user
          @first = result_from_success.call
          @second = result_from_success.call
          @persisted = CryptIdent.config.repository.find(@first.id)
        end

        # Yes, this is horrendous, but it's because Minitest made a horrendous
        # choice itself. Rather than using the `#==` method on classes that
        # support it (like `Time`) and falling back to `#inspect` only when that
        # isn't available, comparing `Time` instances using `must_be_equal_to`
        # or `wont_be_equal_to` compares output from `#inspect`. In the case of
        # the `Time` class, this produces *a string with date, hours, minutes,
        # and seconds.* No sub-second resolution is taken into account. Laziness
        # arguably more than bordering on incompetence.
        it ':password_reset_expires_at' do
          first = @first.password_reset_expires_at
          second = @second.password_reset_expires_at
          persisted = @persisted.password_reset_expires_at
          first = [first.tv_sec, first.tv_usec]
          second = [second.tv_sec, second.tv_usec]
          persisted = [persisted.tv_sec, persisted.tv_usec]
          expect(first).wont_equal second
          expect(second).must_equal persisted
        end

        it 'token' do
          first = @first.token
          second = @second.token
          persisted = @persisted.token
          expect(first).wont_equal second
          expect(second).must_equal persisted
        end
      end # describe 'overwrites any previously-persisted attribute values for'
    end # describe 'the default, nil'

    describe 'the Guest User, as a Hash of attributes' do
      describe 'it passes a User Entity to the result.success block with' do
        let(:actual) { created_user }

        before { _ = actual }

        it 'a valid :token attribute' do
          expect(actual.token).must_be :nil?
          other_params[:current_user] = CryptIdent.config.guest_user.to_h
          actual = result_from_success.call
          token = :unassigned
          # will raise ArgumentError on invalid Base64 input
          token = Base64.strict_decode64(actual.token)
          expect(token.length).must_equal CryptIdent.config.token_bytes
        end
      end # describe 'it passes a User Entity to the result.success block with'
    end # describe 'the Guest User, as a Hash of attributes'
  end # describe 'when supplied a valid User Name and a Current User of'

  describe 'when supplied a Current User other than nil or the Guest User' do
    let(:current_user) { created_user }

    describe 'passes to the result.error block' do
      let(:actual) do
        result_from_failure.call current_user.name, current_user
      end

      it 'a :code value of :user_logged_in' do
        expect(actual[:code]).must_equal :user_logged_in
      end

      it 'a :current_user value of the specified Current User' do
        expect(actual[:current_user]).must_equal current_user
      end

      it 'a :name value of :unassigned' do
        expect(actual[:name]).must_equal :unassigned
      end
    end # describe 'passes to the result.error block'
  end # describe 'when ...a Current User other than nil or the Guest User'

  describe 'when supplied a User Name not found in the Repository' do
    let(:actual) { result_from_failure.call user_name, nil }
    let(:user_name) { 'No Such Name' }

    describe 'passes to the result.error block' do
      it 'a :code value of :user_not_found' do
        expect(actual[:code]).must_equal :user_not_found
      end

      it 'a :name value matching the supplied (not found) User Name' do
        expect(actual[:name]).must_equal user_name
      end

      it 'a :current_user value of the Guest User' do
        expect(actual[:current_user]).must_be :guest?
      end
    end # describe 'passes to the result.error block'
  end # describe 'when supplied a User Name not found in the Repository'
end
