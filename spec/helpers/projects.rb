module Helpers
  module Projects
    def project_dir(name)
      File.join(File.dirname(__FILE__), 'projects', name)
    end
    
    def mock_burke_project(name, &block)
      Dir.chdir project_dir(name) do
        # Stow away current Burke settings and mock out the `settings` method
        Burke.module_eval do
          class << self
            alias :old_settings :settings
            def settings
              @_settings ||= Burke::Settings.new
            end
          end
        end
        
        load 'Rakefile'
        block.call
        
        # Restore Burke to how it was
        Burke.module_eval do
          class << self
            alias :settings :old_settings
          end
        end
      end
    end
  end
end

