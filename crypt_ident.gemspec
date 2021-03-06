# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "crypt_ident/version"

Gem::Specification.new do |spec|
  spec.name          = "crypt_ident"
  spec.version       = CryptIdent::VERSION
  spec.authors       = ["Jeff Dickey"]
  spec.email         = ["jdickey@seven-sigma.com"]

  spec.summary       = %q{Authentication module using BCrypt; initially Hanami-specific.}
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/jdickey/crypt_ident"
  spec.license       = "MIT"
  spec.metadata["yard.run"] = "yri" # use "yard" to build full HTML docs.

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # NOTE: **During development**, we're not specifying Gem versions, because
  # we're bundling locally using `bin/setup` and `scripts/build-gem-list.rb`.
  # Before merging back to `master`, at latest, this **must** be updated to show
  # *minimum* Gem versions; e.g., `'>= 3.1.12'` for `bcrypt`. It Would Be Very
  # Nice if we had a script to automatically rewrite the Gemspec for us each
  # way. PRs welcome.
  #
  # spec.add_runtime_dependency 'bcrypt'
  # spec.add_runtime_dependency 'hanami-model'
  # spec.add_runtime_dependency 'dry-matcher'
  # spec.add_runtime_dependency 'dry-monads'

  # spec.add_development_dependency 'sqlite3'
  # spec.add_development_dependency "bundler", '>= 2.1.4'
  # spec.add_development_dependency "rake", '>= 12.3.3'
  # spec.add_development_dependency "minitest", '5.14.1'
  # spec.add_development_dependency 'flay', '2.12.1'
  # spec.add_development_dependency 'flog', '4.6.4'
  # spec.add_development_dependency 'inch', '0.8.0'
  # # spec.add_development_dependency 'minitest-fail-fast' #, '0.1.0'
  # spec.add_development_dependency 'minitest-hooks', '1.5.0'
  # spec.add_development_dependency 'minitest-matchers', '1.4.1'
  # spec.add_development_dependency 'minitest-reporters', '1.4.2'
  # spec.add_development_dependency 'minitest-tagz', '1.7.0'
  # # XXX: Great idea; useful; but we've found a way to work around what we were
  # # looking to use this Gem to help with.
  # # spec.add_development_dependency 'monotime' #, '0.6.1'
  # spec.add_development_dependency 'pry-byebug', '3.9.0'
  # spec.add_development_dependency 'pry-doc', '1.1.0'
  # spec.add_development_dependency 'parser', '2.6.5.0' # take out when rubocop updated
  # spec.add_development_dependency 'reek', '5.4.0' # should be 6.0.1
  # spec.add_development_dependency 'rubocop', '0.78.0' # should be 0.84.0
  # spec.add_development_dependency 'simplecov', '0.18.5'
  # spec.add_development_dependency 'timecop', '0.9.1'
  # spec.add_development_dependency 'yard', '0.9.25'
  # spec.add_development_dependency 'yard-classmethods', '1.0.0'
  # spec.add_development_dependency 'github-markup', '3.0.4'
  # spec.add_development_dependency 'redcarpet', '3.5.0'

  # spec.add_development_dependency 'guard', '2.16.2'
  # spec.add_development_dependency 'guard-minitest', '2.4.6'
  # spec.add_development_dependency 'guard-rake', '1.0.0'
  # spec.add_development_dependency 'guard-rubocop', '1.3.0'
  # spec.add_development_dependency 'guard-shell', '0.7.1'

  spec.add_runtime_dependency 'bcrypt'
  spec.add_runtime_dependency 'hanami-model'
  spec.add_runtime_dependency 'dry-matcher'
  spec.add_runtime_dependency 'dry-monads'

  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency 'flay'
  spec.add_development_dependency 'flog'
  spec.add_development_dependency 'inch'
  # spec.add_development_dependency 'minitest-fail-fast' #
  spec.add_development_dependency 'minitest-hooks'
  spec.add_development_dependency 'minitest-matchers'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'minitest-tagz'
  # XXX: Great idea; useful; but we've found a way to work around what we were
  # looking to use this Gem to help with.
  # spec.add_development_dependency 'monotime' #
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'pry-doc'
  spec.add_development_dependency 'parser'
  spec.add_development_dependency 'reek'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'yard-classmethods'
  spec.add_development_dependency 'github-markup'
  spec.add_development_dependency 'redcarpet'

  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-minitest'
  spec.add_development_dependency 'guard-rake'
  spec.add_development_dependency 'guard-rubocop'
  spec.add_development_dependency 'guard-shell'
end
