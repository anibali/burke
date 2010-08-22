require File.dirname(__FILE__) + "/spec_helper"

describe Burke do
  subject { Burke }
  
  %w[package_task yard_task spec_task].each do |method|
    it "should respond to .#{method}" do
      Burke.should respond_to method
    end
  end
  
  its(:base_spec) { should be_a Gem::Specification }
end

