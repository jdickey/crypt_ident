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
  spec.homepage      = "https://github.com/jdickey/cript_ident"
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

  spec.add_runtime_dependency 'bcrypt', '>= 3.1.12'
  # hanami-model 1.2.0 depends on *18* other Gems. Just as a reminder...
  spec.add_runtime_dependency 'hanami-model', '>= 1.2.0'
  spec.add_runtime_dependency 'hanami-controller', '>= 1.2.0'

  spec.add_development_dependency "bundler", '>= 1.16.6'
  spec.add_development_dependency "rake", '>= 12.3.1'
  spec.add_development_dependency "minitest", '5.11.3'
  spec.add_development_dependency 'flay', '2.12.0'
  spec.add_development_dependency 'flog', '4.6.2'
  spec.add_development_dependency 'inch', '0.8.0'
  spec.add_development_dependency 'minitest-hooks', '1.5.0'
  spec.add_development_dependency 'minitest-matchers', '1.4.1'
  spec.add_development_dependency 'minitest-reporters', '1.3.5'
  spec.add_development_dependency 'minitest-tagz', '1.6.0'
  spec.add_development_dependency 'pry-byebug', '3.6.0'
  spec.add_development_dependency 'pry-doc', '0.13.4'
  spec.add_development_dependency 'reek', '5.2.0'
  spec.add_development_dependency 'rubocop', '0.60.0'
  spec.add_development_dependency 'simplecov', '0.16.1'
  spec.add_development_dependency 'yard', '0.9.16'
  spec.add_development_dependency 'yard-classmethods', '1.0.0'
  spec.add_development_dependency 'github-markup', '3.0.1'
  spec.add_development_dependency 'redcarpet', '3.4.0'
end
