# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent.config has a reader for' do
  after do
    # These specs are run in random order. If we do not reset `.repository`
    # here after (at least) the `.guest_user` test, then IT WILL STILL BE SET
    # when "verifying" that the default repository value is `nil`.
    # Hilarity ensues.
    CryptIdent.config.repository = nil
  end

  it '.error_key that defaults to :error' do
    expect(CryptIdent.config.error_key).must_equal :error
  end

  it '.hashing_cost that defaults to 8' do
    expect(CryptIdent.config.hashing_cost).must_equal 8
  end

  it '.repository that defaults to nil (DANGER, WILL ROBINSON!)' do
    expect(CryptIdent.config.repository).must_be :nil?
  end

  it '.reset_expiry that defaults to 24 hours' do
    expect(CryptIdent.config.reset_expiry).must_equal (24 * 60 * 60)
  end

  it '.session_expiry that defaults to 15 minutes' do
    expect(CryptIdent.config.session_expiry).must_equal (15 * 60)
  end

  it '.success_key that defaults to :success' do
    expect(CryptIdent.config.success_key).must_equal :success
  end

  it '.token_bytes that defaults to 24' do
    expect(CryptIdent.config.token_bytes).must_equal 24
  end

  describe '.guest_user that returns' do
    it 'a Guest User IF the repository has been set' do
      CryptIdent.config.repository = UserRepository.new
      expect(CryptIdent.config.guest_user.guest?).must_equal true
    end
  end # describe '.guest_user that returns'
end # describe 'CryptIdent.config has a reader for' do
