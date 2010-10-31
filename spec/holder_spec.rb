require 'spec_helper'

describe Burke::Holder do
  before do
    class Person < Burke::Holder
      fields :name, :male
      field(:age) { 18 }
      field(:partner) { Person[:male => !self.male?] }
    end
    
    @holder = Person[:name => "David"]
  end
  
  it "should to retrieve property with []" do
    @holder[:name].should == "David"
  end
  
  it "should retrieve property with method call" do
    @holder.name.should == "David"
  end
  
  it "should yield property to block with with method call" do
    @holder.name {|v| v.should == "David" }
  end
  
  it "should set property with []=" do
    @holder[:name] = "Frodo"
    @holder[:name].should == "Frodo"
  end
  
  it "should set property with plain method call" do
    @holder[:name] = "Frodo"
    @holder[:name].should == "Frodo"
  end
  
  it "should set property with method call ending in '='" do
    @holder[:name] = "Frodo"
    @holder[:name].should == "Frodo"
  end
  
  it "should return false on '?' method when property is unset" do
    @holder.male?.should be_false
  end
  
  it "should return false on '?' method when property is set to false" do
    @holder[:male] = false
    @holder.male?.should be_false
  end
  
  it "should return true on '?' method when property is set to non-nil and non-false value" do
    @holder[:male] = "Yes"
    @holder.male?.should be_true
  end
  
  it "should return default value when property is unset" do
    @holder[:age].should == 18
  end
  
  it "should override default value when property is set" do
    @holder[:age] = 21
    @holder[:age].should == 21
  end
  
  it "should instance_exec block passed to method call for property with Holder value" do
    s = self
    @holder.partner { self.should s.be_a Person }
  end
  
  it "should be able to access other properties from default value block" do
    @holder[:male] = true
    @holder.partner[:male].should be_false
    @holder[:male] = false
    @holder.partner[:male].should be_true
  end
end

