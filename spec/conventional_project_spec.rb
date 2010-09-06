DIR = File.dirname(File.expand_path(__FILE__))
require File.join(DIR, 'spec_helper')

describe Burke do
  describe 'settings' do
    context 'for example of a conventional project' do
      before do
        @old_pwd = Dir.pwd
        Dir.chdir File.join(DIR, 'conventional_project')
        mock_burke_setup
        eval(File.read('Rakefile'))
        @settings = Burke.test_settings
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
      
      after do
        unmock_burke_setup
        Dir.chdir @old_pwd
      end
    end
  end
end

