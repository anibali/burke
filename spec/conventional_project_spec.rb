DIR = File.dirname(File.expand_path(__FILE__))
require File.join(DIR, 'spec_helper')

describe Burke do
  describe 'settings' do
    context 'for example of a conventional project' do
      before do
        Dir.chdir File.join(DIR, 'conventional_project')
        @settings = Burke.create_settings
        eval(File.read('setup_burke.rb')).call @settings
        @settings
      end
      subject { @settings }
      
      its(:name) { should eql 'conventional_project' }
      
      its(:version_file) { should eql 'VERSION' }
      its(:rakefile_file) { should eql 'Rakefile' }
      
      describe 'docs' do
        subject { @settings.docs }
        its(:readme_file) { should eql 'README.md' }
        its(:license_file) { should eql 'COPYING' }
        its(:markup) { should eql 'markdown' }
      end
    end
  end
end

