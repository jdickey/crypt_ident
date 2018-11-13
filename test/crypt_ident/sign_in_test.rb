# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#sign_in' do
  let(:guest_user) { CryptIdent.configure_crypt_ident.guest_user }
  let(:params) do
    { name: 'J Random User', password: 'Suitably Entropic Password!' }
  end
  let(:repo) { UserRepository.new }
  let(:user) { sign_up(params, repo: repo, current_user: nil) }

  describe 'when no Authenticated User is Signed In' do
    describe 'when the correct password is supplied' do
      it 'returns the same User Entity used for Authentication' do
        actual = sign_in(user, params[:password], current_user: nil)
        expect(actual).must_equal user
      end
    end # describe 'when the correct password is supplied'

    describe 'when an incorrect password is supplied' do
      it 'returns nil' do
        actual = sign_in(user, 'B@d Passwrod', current_user: guest_user)
        expect(actual).must_be :nil?
      end
    end # describe 'when an incorrect password is supplied'

    describe 'when Authentication of the Guest User is attempted' do
      it 'returns nil' do
        actual = sign_in(guest_user, 'anything', current_user: nil)
        expect(actual).must_be :nil?
      end
    end # describe 'when Authentication of the Guest User is attempted'
  end # describe 'when no Authenticated User is Signed In'

  describe 'when an Authenticated User is Signed In' do
    let(:other_user) do
      sign_up({ name: 'Another User', password: 'anything' }, current_user: nil)
    end

    it 'fails even with a correct password for a different User' do
      actual = sign_in(user, params[:password], current_user: other_user)
      expect(actual).must_be :nil?
    end
  end # describe 'when an Authenticated User is Signed In'
end
