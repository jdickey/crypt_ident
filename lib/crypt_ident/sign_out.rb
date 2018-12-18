# frozen_string_literal: true

require 'dry/monads/result'
require 'dry/matcher/result_matcher'

# Sign-out logic for CryptIdent
#
# @author Jeff Dickey
# @version 0.1.0
module CryptIdent
  # Sign-out logic for `CryptIdent`, per Issue #9.
  #
  # This class *is not* part of the published API.
  # @private
  class SignOut
    include Dry::Monads::Result::Mixin
    include Dry::Matcher.for(:call, with: Dry::Matcher::ResultMatcher)

    # This method exists, despite YAGNI, to provide for future expansion of
    # features like analytics. More importantly, it provides an API congruent
    # with that of the (reworked) `#sign_up` and `#sign_in` methods.
    def call(current_user:)
      _ = current_user # presently ignored
      Success(config: CryptIdent.cryptid_config)
    end
  end
end
