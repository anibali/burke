$:.unshift File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'

Burke.setup do
  name      'burke'
  summary   'Helper for creating nice, clean Rake files'
  author    'Aiden Nibali'
  email     'dismal.denizen@gmail.com'
  homepage  'http://github.com/dismaldenizen/burke'
  
  clean     %w[.yardoc]
  clobber   %w[pkg doc html coverage]
  
  rspec.rcov.failure_threshold = 65
end

