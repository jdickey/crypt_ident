# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#sign_out' do
  let(:guest_user) { CryptIdent.configure_crypt_ident.guest_user }
  let(:long_ago) { Hanami::Utils::Kernel.Time(0) }
  let(:session) { Hash[] }

  describe 'when an Authenticated User is Signed In' do
    let(:repo) { UserRepository.new }
    let(:user) do
      user_name = 'Some User'
      password = 'Anything'
      password_hash = BCrypt::Password.create(password)
      user = User.new name: user_name, password_hash: password_hash
      our_repo = repo || CryptIdent.configure_crypt_ident.repository
      our_repo.clear # XXX: WTAF?!?
      our_repo.create(user)
    end

    before do
      session[:current_user] = user
      session[:start_time] = Time.now - 60 # 1 minute ago
    end

    it 'and session-data items are reset' do
      sign_out(current_user: session[:current_user]) do |result|
        result.success do
          session[:current_user] = guest_user
          session[:start_time] = long_ago
        end

        result.failure { next }
      end
      # TODO: Consider calling `#session_expired?` once implemented.
      expect(session[:current_user]).must_equal guest_user
      expect(session[:start_time]).must_equal long_ago
    end

    it 'and session-data items are deleted' do
      sign_out(current_user: session[:current_user]) do |result|
        result.success do
          session[:current_user] = nil
          session[:start_time] = nil
        end

        result.failure { next }
      end
      # NOTE: [Setting session data to `nil`](https://github.com/hanami/controller/blob/234f31c/lib/hanami/action/session.rb#L56-L57)
      # deletes it, in normal Rack/Hanami/etc usage. To simulate that with a
      # real Hash instance, we call `#compact!`.
      session.compact!
      expect(session.to_h).must_be :empty?
    end
  end # describe 'when an Authenticated User is Signed In'

  describe 'when no Authenticated User is Signed In' do
    it 'and session-data items are reset' do
      sign_out(current_user: nil) do |result|
        result.success do
          session[:current_user] = guest_user
          session[:start_time] = long_ago
        end

        result.failure { next }
      end
      # TODO: Consider calling `#session_expired?` once implemented.
      expect(session[:current_user]).must_equal guest_user
      expect(session[:start_time]).must_equal long_ago
    end

    it 'and session-data items are deleted' do
      sign_out(current_user: guest_user) do |result|
        result.success do
          session[:current_user] = nil
          session[:start_time] = nil
        end

        result.failure { next }
      end
      # NOTE: See NOTE above.
      session.compact!
      expect(session.to_h).must_be :empty?
    end
  end
end
