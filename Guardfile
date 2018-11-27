# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :minitest do
  watch(%r{^test/(.*)\/?test_(.*)\.rb$})
  watch(%r{^lib/(.*/?[^/]+)\.rb$}) { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/test_helper\.rb$})      { 'test' }
end

guard 'rake', task: 'flay' do
  watch(%r{^lib/.*/?[^/]+\.rb$})
end

# guard 'rake', task: 'flog', run_on_all: true, run_on_start: true do
#   # watch(%r{^lib/.*/?[^/]+\.rb$})
# end

guard :shell do
  watch(%r{^lib/.*/?[^/]+\.rb$})     { |m| "bin/flog -adm #{m[0]}" }
  watch(%r{^lib/.*/?[^/]+\.rb$})     { |m| "bin/reek -c config.reek --sort-by smelliness #{m[0]}" }
  watch(%r{^lib/.*/?[^/]+\.rb$})     { |m| "bin/inch list #{m[0]}" }
end

guard :rubocop do
  watch(%r{^lib/crypt_ident/.*?[^/]+\.rb$})
end
