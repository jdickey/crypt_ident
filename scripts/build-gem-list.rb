#!/usr/bin/env ruby
#
# This file exists to build the list of Gem dependencies explicitly named in the
# `.gemspec` *and* in those Gems' dependencies. It includes Gems used in
# *either* runtime *or development.* Gem versions may be specified explicitly in
# the `.gemspec` (e.g., `foo-bar:1.4.6`) or implicitly (`foo-bar`), which will
# select the latest version of that Gem. All specified Gems and their
# dependencies are resolved (see `#gem_strings`) to produce a set of Gem version
# specifications that are compatible with each other (if that is possible).
#
# Experience has shown that *not* having a fully-resolved set of Gems, or
# relying on the Gemfiles of client apps to Do The Right Thing, is a reciple for
# a) insanity and b) the utter waste of arbitrary, non-trivial amounts of time
# playing Whac-A-Mole(TM) with N-to-the-N independently moving parts.
#
# Since this is a Gem rather than an application, there is a *vitally important*
# assumption that the `.gemspec` specifies correct, compatible versions of all
# dependencies. This can be guided by hand-specifying the Gem versions in the
# `.gemspec` based on the `Gemfile.lock` last produced by running this script
# and then bundling.
#
# TBD: It Would Be Very Nice If(tm) the code producing the list of resolved Gems
# were to itself be packaged up in a Gem with two API entrypoints, such as
# `GemList.from_app_gemfile` and `GemList.from_gem_gemspec`. That would largely
# eliminate the need to copy and hand-edit this script file.

def deps_for(name_spec)
  name, version = name_spec.split(':')
  version ||= Gem.latest_version_for(name)
  dependent = Gem::Dependency.new name, version
  deps = Array(Gem.latest_spec_for(name.to_s).dependencies)
  # Eliminate dependencies' development-mode Gems
  deps = [dependent] + deps.reject { |gem| gem.type == :development }
  deps.flatten # .sort
end

def all_deps_for(list)
  list.map { |gem| deps_for(gem) }.flatten # .sort
end

def gem_strings(list)
  resolved = Gem::Resolver.new(all_deps_for(list)).resolve
  resolved.map { |req| req.full_name.sub(/\-(\d)/, ':\1') }
end

list = File.open('crypt_ident.gemspec', 'r') do |f|
  f.lines.to_a.
  map(&:strip).
  select { |line| line.start_with?(/spec.add_/) }.
  map { |line| line.sub(/spec.add_.+_dependency ["'](.+)["']/, '\1') }
end

# require 'pry-byebug'; binding.pry
puts gem_strings(list).join(' ')
