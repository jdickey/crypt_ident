# frozen_string_literal: true

# Authenticated-User Password-change logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Password-change logic for `CryptIdent`, extracted from original
  # `#change_password` method.
  #
  # This class *is not* part of the published API.
  # @private
  class ChangePassword
    # Reek complains about :reek:ControlParameter for `repo`. Oh, well.
    def initialize(config:, repo:, user:)
      @repo = repo || config.repository
      @user = user
      @updated_attribs = nil
    end

    def call(current_password, new_password)
      return :invalid_user unless valid_user?
      return :bad_password unless valid_password?(current_password)

      update(new_password)
    end

    private

    attr_reader :repo, :updated_attribs, :user

    def update(new_password)
      update_attribs(new_password)
      repo.update(user.id, updated_attribs)
    end

    def update_attribs(new_password)
      new_hash = ::BCrypt::Password.create(new_password)
      @updated_attribs = { password_hash: new_hash, updated_at: Time.now }
    end

    def valid_password?(password)
      user.password_hash == password
    end

    def valid_user?
      _ = user.password_hash
      !user.guest_user?
    rescue NoMethodError
      false
    end
  end # class CryptIdent::ChangePassword
end
