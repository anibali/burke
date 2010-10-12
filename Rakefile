$LOAD_PATH << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'

Burke.enable_all

Burke.setup do
  name      'burke'
  summary   'Helper for creating nice and clean Rake files'
  author    'Aiden Nibali'
  email     'dismal.denizen@gmail.com'
  homepage  'http://github.com/dismaldenizen/burke'
  
  clean     %w[.yardoc]
  clobber   %w[pkg doc html]
  
  dependencies do
    rake      '0.8.7'
  end
  
  rspec.rcov.failure_threshold = 42.6
end

