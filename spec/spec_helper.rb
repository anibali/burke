$LOAD_PATH << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'burke'

def mock_burke_setup
  Burke.module_eval do
    class << self
      attr_reader :test_settings
      alias :old_setup :setup
      
      def setup
        @test_settings = create_settings
        yield @test_settings
      end
    end
  end
end

def unmock_burke_setup
  Burke.module_eval do
    class << self
      alias :setup :old_setup
    end
  end
end

