$LOAD_PATH << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'

Burke.setup do
  name      'burke'
  summary   'Helper for creating nice, clean Rake files'
  author    'Aiden Nibali'
  email     'dismal.denizen@gmail.com'
  homepage  'http://github.com/dismaldenizen/burke'
  
  clean     %w[.yardoc]
  clobber   %w[pkg doc html coverage]
  
  rspec.rcov.failure_threshold = 74
end

desc  "Run RSpec code examples with RCov"
RSpec::Core::RakeTask.new('spec:rcov:verify') do |t|
  t.rcov = true
  t.rcov_opts = [
    '--failure-threshold', Burke.settings.rspec.rcov.failure_threshold,
    '-Ilib',
    '--exclude', 'spec/,Rakefile',
    '--no-html'
  ]
end

