require 'lib/burke'

require 'rake/clean'
CLOBBER.include("pkg", "doc", ".yardoc")

Burke.base_spec do |s|
  s.name = 'burke'
  s.version = Burke::VERSION
  s.summary = 'Helper for creating nice and clean Rake files'
  s.description = s.summary
  s.author = 'Aiden Nibali'
  s.email = 'dismal.denizen@gmail.com'
  s.homepage = "http://github.com/dismaldenizen/burke"
  
  s.add_dependency 'rake', '~> 0.8.7'
  
  s.files = FileList['lib/**/*.rb']
end

Burke.package_task

Burke.install_task

Burke.yard_task do |t|
  t.options = [
    '--title', "Burke #{Burke::VERSION}",
    '--readme', 'README.md',
    '-m', 'markdown'
  ]
end

Burke.spec_task 'spec' do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts << '--colour --format progress'
  t.ruby_opts << '-rubygems'
end

