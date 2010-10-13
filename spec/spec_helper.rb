$LOAD_PATH << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'
require 'rspec/core'

def mock_burke_setup
  Burke.module_eval do
    class << self
      alias :old_settings :settings
      
      def settings
        @settings ||= Burke::Settings.new
      end
    end
  end
end

def unmock_burke_setup
  Burke.module_eval do
    class << self
      alias :settings :old_settings
    end
  end
end

