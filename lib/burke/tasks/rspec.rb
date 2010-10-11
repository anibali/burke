module Burke
  Settings.field(:rspec) { self.rspec = RSpecSettings.new }
  
  define_task 'spec' do |s|
    begin
      require 'rspec/core/rake_task'
      
      r = s.rspec
      opts = build_rspec_opts r
      
      RSpec::Core::RakeTask.new 'spec' do |t|
        t.ruby_opts = r.ruby_opts if r.ruby_opts
      end
    rescue LoadError
    end
  end
  
  def self.build_rspec_opts r
    opts = []
    opts << "--colour" if r.color
    opts << "--format" << r.format if r.format
    opts
  end
  
  class RCovSettings < Holder
    field 'threshold'
  end
  
  class RSpecSettings < Holder
    field('color') { true }
    field('format') { 'progress' }
    
    field 'ruby_opts'
    field('rcov') { self.rcov = RCovSettings.new }
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
end

