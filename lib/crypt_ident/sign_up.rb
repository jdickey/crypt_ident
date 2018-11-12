# frozen_string_literal: true

require 'securerandom'

# Sign-up logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Sign-up logic for `CryptIdent`, extracted from original `#sign_up` method.
  #
  # This class *is not* part of the published API.
  # @private
  class SignUp
    def initialize(repo = nil)
      @ci_config = config_with_repo(repo)
      @result = nil
      @success = false
    end

    def call(attribs, on_error: nil)
      create_result(all_attribs(attribs))
      call_block_with_result(on_error) do
        yield result, ci_config # Always yield; API method decides what to do.
      end
      result
    end

    private

    attr_reader :ci_config, :result, :success

    def all_attribs(attribs)
      password_hash = hashed_password(attribs[:password])
      { password_hash: password_hash }.merge(attribs)
    end

    # Reek sees a :reek:NilCheck in the `on_error` call. Yep.
    def call_block_with_result(on_error)
      if success
        yield
      else
        on_error&.call(result, ci_config)
      end
    end

    def config_with_repo(repo)
      config_hash = CryptIdent.configure_crypt_ident.to_h
      config_hash[:repository] = repo if repo
      Config.new config_hash
    end

    def create_result(all_attribs)
      @result = ci_config.repository.create(all_attribs)
      @success = true
    rescue Hanami::Model::UniqueConstraintViolationError
      @result = :user_already_created
    rescue Hanami::Model::Error
      @result = :user_creation_failed
    end

    def hashed_password(password_in)
      password = password_in.to_s.strip
      password = SecureRandom.urlsafe_base64(64) if password.empty?
      ::BCrypt::Password.create(password)
    end
  end # class CryptIdent::SignUp
end
