# frozen_string_literal: true

require 'test_helper'

describe 'UserRepository Fixture' do
  let(:initial_attributes) do
    { name: 'Sophie de Bar', password_hash: initial_password_hash }
  end
  let(:initial_password_hash) { BCrypt::Password.create('Ardennes') }
  let(:repository) { UserRepository.new }
  let(:user) { repository.create(initial_attributes) }

  it 'returns the created object instance using #find' do
    expect(repository.find(user.id).object_id).must_equal user.object_id
  end

  it 'returns a different object instance using #update' do
    new_password_hash = BCrypt::Password.create('Forest')
    new_user = repository.update(user.id, password_hash: new_password_hash)
    expect(new_user.object_id).wont_equal user.object_id
  end
end
