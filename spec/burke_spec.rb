($LOAD_PATH << File.dirname(File.expand_path(__FILE__))).uniq!
require 'spec_helper'

DIR = File.dirname(File.expand_path(__FILE__))

describe Burke do
  describe 'settings' do
    context 'for example of a simple project' do
      before do
        @old_pwd = Dir.pwd
        Dir.chdir File.join(DIR, 'simple_project')
        mock_burke_setup
        load 'Rakefile'
        @settings = Burke.settings
      end
      
      subject { @settings }
      
      its(:name) { should eql 'simple_project' }
      
      its(:version_file) { should eql 'VERSION' }
      its(:rakefile_file) { should eql 'Rakefile' }
      its(:version) { should eql '1.2.3' }
      
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

