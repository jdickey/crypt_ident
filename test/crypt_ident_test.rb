# frozen_string_literal: true

require 'test_helper'

describe 'CryptIdent' do
  it 'has a version number in SemVer format with at least three numbers' do
    parts = CryptIdent::VERSION.split('.')
    actual = parts[0, 3].detect { |item| item.to_i.to_s != item }
    expect(actual).must_be :nil?
  end
end
