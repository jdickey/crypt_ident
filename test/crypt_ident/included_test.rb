# frozen_string_literal: true

require 'test_helper'

include CryptIdent

describe 'CryptIdent.included' do
  it 'defines the module-added instance variable' do
    actual = CryptIdent.instance_variable_get(:@cryptid_config)
    expect(actual).must_equal CryptIdent.configure_crypt_ident
  end

  it 'adds the cryptid_config reader method to the module' do
    expected = CryptIdent.configure_crypt_ident
    expect(CryptIdent.cryptid_config).must_equal expected
  end
end
