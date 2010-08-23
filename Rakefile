$LOAD_PATH << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'

Burke.enable_all

Burke.setup do |s|
  s.name = 'burke'
  s.summary = 'Helper for creating nice and clean Rake files'
  s.description = s.summary
  s.author = 'Aiden Nibali'
  s.email = 'dismal.denizen@gmail.com'
  s.homepage = "http://github.com/dismaldenizen/burke"
  
  s.dependencies do |d|
    d.rake '~> 0.8.7'
  end
  
  s.files = %w[README.rdoc Rakefile VERSION] + Dir.glob('{lib,spec}/**/*')
  s.clean = %w[.yardoc]
  s.clobber = %w[pkg doc html]
  
  s.docs do |d|
    d.readme = 'README.rdoc'
    d.markup = 'rdoc'
  end
  
  s.rspec do |r|
    r.spec_files = FileList['spec/**/*_spec.rb']
    r.color = true
  end
  
  s.gems do |g|
    g.platform 'ruby'
  end
end

