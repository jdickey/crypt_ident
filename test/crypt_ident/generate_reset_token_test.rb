# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#generate_reset_token' do
  let(:created_user) do
    ret = :unassigned
    sign_up(user_params, other_params) do |result|
      result.success { |user:, config:| ret = user }
      result.failure { next }
    end
    ret
  end
  let(:other_params) { { repo: repo, current_user: nil } }
  let(:user_params) do
    { name: 'J Random Someone', password: 'A Password' }
  end

  describe 'using an explicitly-supplied Repository' do
    let(:repo) { CryptIdent.configure_crypt_ident.repository }
    let(:result_from_success) do
      lambda do
        the_user = :unassigned
        generate_reset_token(user_params[:name], other_params) do |result|
          result.success { |user:| the_user = user }
          result.failure { next }
        end
        the_user
      end
    end
    let(:result_from_failure) do
      lambda do |user_name, current_user|
        the_code = the_current_user = the_name = :unassigned
        other_params = { repo: repo, current_user: current_user }
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

    describe 'when supplied a valid User Name and no Current User' do
      describe 'it passes a User Entity to the result.success block with' do
        let(:actual) { created_user }

        before do
          repo.clear
          _ = actual
        end

        it 'a valid :token attribute' do
          expect(actual.token).must_be :nil?
          actual = result_from_success.call
          token = :unassigned
          # will raise ArgumentError on invalid Base64 input
          token = Base64.strict_decode64(actual.token)
          expect(token).wont_equal :unassigned
        end

        it 'a valid :password_reset_sent_at attribute' do
          expect(actual.password_reset_sent_at).must_be :nil?
          actual = result_from_success.call
          elapsed = Time.now - actual.password_reset_sent_at
          expect(elapsed).must_be :<, 5 # seconds
        end
      end # describe 'it passes a User Entity to the result.success block with'

      it 'persists the updated Entity to the Repository' do
        _ = created_user
        entity = result_from_success.call
        expect(repo.first).must_equal entity
        expect(repo.all.count).must_equal 1
      end

      describe 'overwrites any previously-persisted attribute values for' do
        before do
          repo.clear
          _ = created_user
          @first = result_from_success.call
          @second = result_from_success.call
          @persisted = repo.find(@first.id)
        end

        # Yes, this is horrendous, but it's because Minitest made a horrendous
        # choice itself. Rather than using the `#==` method on classes that
        # support it (like `Time`) and falling back to `#inspect` only when that
        # isn't available, comparing `Time` instances using `must_be_equal_to`
        # or `wont_be_equal_to` compares output from `#inspect`. In the case of
        # the `Time` class, this produces *a string with date, hours, minutes,
        # and seconds.* No sub-second resolution is taken into account. Laziness
        # arguably more than bordering on incompetence.
        it ':password_reset_sent_at' do
          first = @first.password_reset_sent_at
          second = @second.password_reset_sent_at
          persisted = @persisted.password_reset_sent_at
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
    end # describe 'when supplied a valid User Name and no Current User'

    describe 'when supplied a Current User other than nil or the Guest User' do
      let(:current_user) { created_user }

      before do
        repo.clear
      end

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
          expect(actual[:current_user].guest_user?).must_equal true
        end
      end # describe 'passes to the result.error block'
    end # describe 'when supplied a User Name not found in the Repository'
  end # describe 'using an explicitly-supplied Repository'

  describe 'using the config-default Repository' do
    let(:created_user) do
      ret = :unassigned
      sign_up(user_params, other_params) do |result|
        result.success { |user:, config:| ret = user }
        result.failure { next }
      end
      ret
    end
    let(:other_params) { { repo: repo, current_user: nil } }
    let(:repo) { nil }
    let(:user_params) do
      { name: 'J Random Someone', password: 'A Password' }
    end
    let(:result_from_success) do
      lambda do
        the_user = :unassigned
        generate_reset_token(user_params[:name], other_params) do |result|
          result.success { |user:| the_user = user }
          result.failure { next }
        end
        the_user
      end
    end

    describe 'when supplied a valid User Name and no Current User' do
      describe 'it passes a User Entity to the result.success block with' do
        let(:actual) { created_user }

        before do
          CryptIdent.configure_crypt_ident.repository.clear
          _ = actual
        end

        it 'a valid :token attribute' do
          expect(actual.token).must_be :nil?
          actual = result_from_success.call
          token = :unassigned
          # will raise ArgumentError on invalid Base64 input
          token = Base64.strict_decode64(actual.token)
          expect(token).wont_equal :unassigned
        end

        it 'a valid :password_reset_sent_at attribute' do
          expect(actual.password_reset_sent_at).must_be :nil?
          actual = result_from_success.call
          elapsed = Time.now - actual.password_reset_sent_at
          expect(elapsed).must_be :<, 5 # seconds
        end
      end # describe 'it passes a User Entity to the result.success block with'

      it 'persists the updated Entity to the Repository' do
        _ = created_user
        entity = result_from_success.call
        repo = CryptIdent.configure_crypt_ident.repository
        expect(repo.first).must_equal entity
        expect(repo.all.count).must_equal 1
      end

      describe 'overwrites any previously-persisted attribute values for' do
        before do
          CryptIdent.configure_crypt_ident.repository.clear
          _ = created_user
          @first = result_from_success.call
          @second = result_from_success.call
          @persisted = CryptIdent.configure_crypt_ident.repository
            .find(@first.id)
        end

        # Yes, this is horrendous, but it's because Minitest made a horrendous
        # choice itself. Rather than using the `#==` method on classes that
        # support it (like `Time`) and falling back to `#inspect` only when that
        # isn't available, comparing `Time` instances using `must_be_equal_to`
        # or `wont_be_equal_to` compares output from `#inspect`. In the case of
        # the `Time` class, this produces *a string with date, hours, minutes,
        # and seconds.* No sub-second resolution is taken into account. Laziness
        # arguably more than bordering on incompetence.
        it ':password_reset_sent_at' do
          first = @first.password_reset_sent_at
          second = @second.password_reset_sent_at
          persisted = @persisted.password_reset_sent_at
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
    end # describe 'when supplied a valid User Name and no Current User'
  end # describe 'using the config-default Repository'
end