Burke
=====

Synopsis
--------

Burke provides a bunch of helpers to make creating Rake files a little more
pleasant. It is named after Don Burke, host of an Australian gardening and
home improvement show named [Burke's Backyard](http://www.burkesbackyard.com.au/).

Features
--------

* DRY definition of Gem packages for multiple platforms
* Recovery from missing libraries like Yard and RSpec

Example
-------

Here is a sample Rakefile using Burke.

    require 'rubygems'
    require 'burke'
    require 'fileutils'
    
    # Define the base Gem specification
    Burke.base_spec do |s|
      s.name = 'foo'
      s.version = '1.2.3'
      s.summary = 'an example Ruby library with extra foo'
      s.files = FileList['lib/**/*.rb']
    end
    
    # Create task for building a platform-independent Gem from the base spec
    Burke.package_task
    
    # Create task for building a 32-bit Linux Gem, extending the base spec
    # and performing extra duties. Task has a custom description.
    desc "I'm too l337 for stock descriptions"
    Burke.package_task 'x86-linux' do |t|
      t.before do
        FileUtils.copy 'native/libfoo-x86-linux.so', 'lib/libfoo.so'
      end
      
      t.extend_spec do |s|
        s.add_dependency 'ffi'
        
        s.files += ['lib/libfoo.so']
      end
      
      t.after do
        FileUtils.remove 'lib/libfoo.so'
      end
    end
    
    # Create task for building Yard docs. If Yard is not available, a warning
    # will be generated instead of Rake crashing.
    Burke.yard_task do |t|
      t.options = [
        '--title', "Foo",
        '--readme', 'README'
      ]
    end

