# frozen_string_literal: true

# This is an integration test for CryptIdent. Integration tests differ from
# unit tests in that they're more use-case oriented; rather than iteratively
# testing every feature and error handler of a module or class, they demonstrate
# a sequence illustrating how the code would be used to "tell an end-to-end
# story". Development-only tools such as test coverage analysis, or mocks of
# framework classes, aren't used.
#
# This test exercises the following sequence of actions:
#
# 1. A new Member is Registered. This generates a Token which a client app would
#    send to the new Member via email, usually embedded within a URL that the
#    Member would visit to confirm identity. For our purposes, we simply capture
#    the Token for use in the following step. The test verifies that this
#    completes successfully by inspecting the Result monad returned from
#    `#sign_up`.
# 2. Use the Token from the first step to perform a Password Reset and set a
#    (new) Password for the Member. We inspect the Result returned from
#    `#password_reset` to verify success; once verified, we continue to the next
#    step.
# 3. Using the newly-specified Password, the Member is Signed In. The test
#    inspects the return value from `#sign_in` to verify success. (Since
#    management of the `current_user` stored in session data is outside the
#    scope of this Gem, no additional means exists to verify the autnentication
#    status of a Member).
# 4. The Member is Signed Out. The test verifies that this is reported as
#    successful by the `#sign_out` method; see the earlier step for a discussion
#    of why no additional verification means is available.
# 5. Attempt to Register a new Member using the same information as in the
#    previous step. The test verifies that this fails and that the `#sign_up`
#    method indicates that the Member already exists.
#
# Again, why do this as opposed to simply trusting unit tests, or waiting until
# a "real app" can test them? We want to be able to test in an environment that
# is
#
# 1. Integrated: This and similar, associated tests are part of the CryptIdent
#    Gem source tree; they'll be maintained going forward as needed to exercise
#    any changes in the CryptIdent API;
# 2. Realistic: By not requiring 'test_helper.rb', we're not including the mock
#    Repository class; we're not including analysis tools like SimpleCov; and we
#    *shouldn't be* exercising any fancy auto-loading beyond what an actual user
#    of the `crypt_ident` Gem would. By doing so, we can eliminate false
#    negatives for failures encountered with the 0.1.*x* releases of this Gem;
# 3. Confidence-building: These tests *only* deal with the API-level interface
#    to CryptIdent, allowing us to reimplement internals when justified and
#    prove that code which had worked before will continue to. Similarly, these
#    tests will break if existing APIs are changed; this can be a valuable
#    resource for documenting changes required to client code to work with the
#    new version.

################################################################################
#                                                                              #
#                             Set up for Minitest                              #
#                                                                              #
################################################################################

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/tagz'

tags = ENV['TAGS'].split(',') if ENV['TAGS']
tags ||= []
tags << 'focus'
Minitest::Tagz.choose_tags(*tags, run_all_if_no_match: true)

################################################################################
#                                                                              #
#                        Our User Model and Repository                         #
#                                                                              #
################################################################################

require 'hanami/model'
require 'securerandom'

class User < Hanami::Entity
  GUEST_EMAIL = 'guest@example.com'
  GUEST_NAME = 'Guest User'
  GUEST_PROFILE = 'This is the Guest User. It can do nothing.'

  def guest?
    name == GUEST_NAME && email == GUEST_EMAIL && profile == GUEST_PROFILE
  end
end

class UserRepository < Hanami::Repository
  def find_by_token(token)
    users.where(token: token).map_to(User).one
  end

  def guest_user
    @guest_user ||= User.new name: User::GUEST_NAME, email: User::GUEST_EMAIL,
                             password_hash: SecureRandom.alphanumeric(48),
                             profile: User::GUEST_PROFILE
  end
end

################################################################################
#                                                                              #
#                   Bringing up Hanami::Model and ecosystem                    #
#                                                                              #
################################################################################

ENV['SQLITE_PATH'] = 'sqlite://tmp/dummy_data.sqlite'
FileUtils.touch './tmp/dummy_data.sqlite'

require 'fileutils'
require 'hanami/model/sql'
require 'hanami/model/migrator'
require 'hanami/model/migration'

module DatabaseHelper
  MAPPING = {
    'postgres' => 'POSTGRES_URL',
    'mysql' => 'MYSQL_URL',
    'sqlite' => 'SQLITE_PATH',
  }

  module_function

  def adapter
    ENV['DB'] || 'sqlite'
  end

  def postgres?
    adapter == 'postgres'
  end

  def db_url(desired_adapter = nil)
    env_name = MAPPING.fetch(desired_adapter || adapter)
    ENV[env_name]
  end
end

Hanami::Model.configure do
  adapter :sql, DatabaseHelper.db_url
  logger 'tmp/database.log', level: :debug
  migrations Pathname.new(__dir__ + '/fixtures/migrations').to_s
end
Hanami::Model::Migrator.migrate
Hanami::Model.load!

################################################################################
#                                                                              #
#                               TESTS START HERE                               #
#                                                                              #
################################################################################

require 'crypt_ident'

include CryptIdent

describe 'Iterating the steps in the New Member workflow' do
  let(:email) { 'jrandom@example.com' }
  let(:member_name) { 'J Random Member' }
  let(:password) { 'A Suitably Entropic Passphrase Goes Here' }
  let(:profile) { 'Profile content would go here.' }

  before do
    CryptIdent.config.repository = UserRepository.new
  end

  after do
    CryptIdent.config.repository.clear
  end

  it 'succeeds along the normal path' do
    # Register a New Member
    sign_up_params = { name: member_name, profile: profile, email: email }
    the_user = the_code = the_config = :unassigned
    CryptIdent.sign_up(sign_up_params, current_user: nil) do |result|
      result.success do |config:, user:|
        the_config = config
        the_user = user
      end
      result.failure do |code:, config:|
        expect(code).must_equal :unassigned # will fail and report actual code
        the_code = code
        the_config = config
      end
    end
    expect(the_code).must_equal :unassigned
    expect(the_user).wont_equal :unassigned
    # FIXME: `config:` as a Result parameter should be removed
    expect(the_config).must_equal CryptIdent.config

    # Perform a Password Reset

    the_token = the_user.token
    old_password_hash = the_user.password_hash
    the_user = :unassigned
    CryptIdent.reset_password(the_token, password) do |result|
      result.success do |user:|
        the_user = user
      end

      result.failure do |code:, config:, token:|
        expect(code).must_equal :unassigned # fail and report actual code
      end
    end
    expect(the_user.password_hash).wont_equal old_password_hash

    # Sign In

    signed_in_user = :unassigned
    CryptIdent.sign_in(the_user, password) do |result|
      result.success { |user:| signed_in_user = user }
      result.failure { |code:| expect(code).must_equal :unassigned }
    end
    expect(signed_in_user).must_equal the_user

    # Sign Out

    the_config = :unassigned
    CryptIdent.sign_out(current_user: nil) do |result|
      result.success { |config:| the_config = config }
      result.failure { expect(nil).wont_be :nil? } # Should *never* fire.
    end
    expect(the_config).must_equal CryptIdent.config
  end
end
