# frozen_string_literal: true

Hanami::Model.migration do
  change do
    create_table :users do
      primary_key :id

      column :name, String, null: false, unique: true, index: true
      column :email, String, null: false, unique: true
      column :profile, 'text', default: ''
      column :password_hash, String, null: false
      column :password_reset_expires_at, Time
      column :token, String

      column :created_at, DateTime, null: false
      column :updated_at, DateTime, null: false
    end
  end
end
