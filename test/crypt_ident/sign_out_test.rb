# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent#sign_out' do
  let(:guest_user) { CryptIdent.cryptid_config.guest_user }
  let(:far_future) { Time.now + 100 * 365 * 24 * 3600 } # 100 years should do...
  let(:session) { Hash[] }

  describe 'when an Authenticated User is Signed In' do
    let(:repo) { UserRepository.new }
    let(:user) do
      user_name = 'Some User'
      password = 'Anything'
      password_hash = BCrypt::Password.create(password)
      user = User.new name: user_name, password_hash: password_hash
      our_repo = repo || CryptIdent.cryptid_config.repository
      our_repo.create(user)
    end

    before do
      our_repo = repo || CryptIdent.cryptid_config.repository
      our_repo.clear
      session[:current_user] = user
      session[:start_time] = Time.now - 60 # 1 minute ago
    end

    it 'and session-data items are reset' do
      sign_out(current_user: session[:current_user]) do |result|
        result.success do
          session[:current_user] = guest_user
          session[:start_time] = far_future
        end

        result.failure { next }
      end
      # We had been considering calling `#session_expired?` here, as in
      # `expect(session_expired(session)).must_equal true` *but...* that API
      # has changed since when we first put the 'todo' note in, which suggests
      # that it's an SRP-level Bad Idea. Removing the note; taking the cannoli.
      expect(session[:current_user]).must_equal guest_user
      expect(session[:start_time]).must_equal far_future
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
          session[:start_time] = far_future
        end

        result.failure { next }
      end
      expect(session[:current_user]).must_equal guest_user
      expect(session[:start_time]).must_equal far_future
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
