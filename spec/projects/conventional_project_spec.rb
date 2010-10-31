require 'spec_helper'
require 'helpers/projects'

describe "conventional project" do
  include Helpers::Projects
  
  around do |example|
    mock_burke_project('conventional', &example) 
  end
  
  let(:settings) { Burke.settings }
  subject { settings }
  
  its(:name) { should eql 'conventional' }
  
  its(:version_file) { should eql 'VERSION' }
  its(:rakefile_file) { should eql 'Rakefile' }
  its(:version) { should eql '1.2.3' }
  
  describe 'docs' do
    subject { settings.docs }
    its(:readme_file) { should eql 'README.md' }
    its(:license_file) { should eql 'COPYING' }
    its(:markup) { should eql 'markdown' }
  end
  
  describe 'test' do
    subject { settings.test }
    its(:files) { should eql ['test/foo_test.rb'] }
  end
end


