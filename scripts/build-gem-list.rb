#!/usr/bin/env ruby
#
# This file exists to build the list of Gems to be installed in images built
# using the Dockerfiles (see `build-dockerfiles.rb`). Note that the list of Gems
# used for testing (copied from that used for image Version 0.1.9) has version
# numbers specified for *each Gem*. Notice further that each Gem specified would
# be explicitly included in a `Gemfile` (as of Conversagence `dev-14` builds),
# rather than dependencies of such Gems (`dry-monads` is a special case.) These
# two aspects are **critically important** to making this whole system work
# correctly. Experience has shown that *not* having a set of Gems locked down in
# this manner, or relying on the Gemfiles of client apps to Do The Right Thing,
# is a recipe for a) insanity and b) the utter waste of arbitrary, non-trivial
# amounts of time playing Whac-A-Mole(TM) with N-to-the-N independently moving
# parts.
#

def deps_for(name_spec)
  name, version = name_spec.split(':')
  version ||= Gem.latest_version_for(name)
  dep = Gem::Dependency.new name, version
  deps = Array(Gem.latest_spec_for(name.to_s).dependencies)
  deps = [dep] + deps.reject { |gem| gem.type == :development }
  deps.flatten.sort
end

def all_deps_for(list)
  list.map { |gem| deps_for(gem) }.flatten.sort
end

# `list` must be in order as per client Gemfile; to get the values for `list`,
# run the following in a Pry session in the directory containing the Gemfile:
#
# list = File.open('Gemfile', 'r') do |f|
#   f.lines.to_a }.
#   map(&:strip).
#   select { |s| s.start_with? 'gem ' }.
#   map { |str| str[5..-1] }.
#   map { |str| str.sub(/(\w)\'.*$/, '\1') }
# end

def gem_strings(list)
  resolved = Gem::Resolver.new(all_deps_for(list)).resolve
  resolved.map { |req| req.full_name.sub(/\-(\d)/, ':\1') }
end

list = [
  'bcrypt:3.1.12',
  'dry-matcher:0.7.0',
  'dry-monads:1.1.0',
  'flay:2.12.0',
  'flog:4.6.2',
  'github-markup:3.0.2',
  'guard:2.15.0',
  'guard-minitest:2.4.6',
  'guard-rake:1.0.0',
  'guard-rubocop:1.3.0',
  'guard-shell:0.7.1',
  # 'hanami-controller:1.3.0',
  'hanami-model:1.3.0',
  'inch:0.8.0',
  # 'minitest-fail-fast:0.1.0',
  'minitest-hooks:1.5.0',
  'minitest-matchers:1.4.1',
  'minitest-reporters:1.3.5',
  'minitest-tagz:1.6.0',
  'minitest:5.11.3',
  # XXX: A useful Gem, but not needed for what we were considering using it for
  # immediately.
  # 'monotime:0.6.1',
  'pry-byebug:3.6.0',
  'pry-doc:1.0.0',
  'rake:12.3.2',
  'redcarpet:3.4.0',
  'reek:5.3.0',
  'rubocop:0.62.0',
  'simplecov:0.16.1',
  'yard-classmethods:1.0.0',
  'yard:0.9.16',
  'sqlite3'
]

# pp [:file, __FILE__]
# gemspec = Gem::Specification.load(File.expand_path('../../crypt_ident.gemspec',
#       __FILE__))
# pp [:gemspec, gemspec.dependencies.map(&:to_s)]
# list2 = gemspec.dependencies.map do |dep|
#   [dep.name, dep.to_spec.version.to_s].join(':')
# end

# require 'pry-byebug'; binding.pry
puts gem_strings(list).join(' ')
