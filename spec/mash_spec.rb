require File.join(File.dirname(File.expand_path(__FILE__)), 'spec_helper')

describe Mash do
  context "when representing {:num => 42}" do
    subject { Mash[:num => 42] }
    its(:num) { should eql 42 }
    its(:size) { should eql 1 }
    its(:to_hash) { should eql :num => 42 }
  end
end

