module Burke
  Settings.field(:rspec) { self.rspec = RSpecSettings.new }
  
  define_task 'spec' do |s|
    begin
      require 'rspec/core/rake_task'
      RSpec::Core::RakeTask.new 'spec' do |t|
        build_spec_task t, s.rspec
      end
    rescue LoadError
    end
  end
  
  define_task 'spec:rcov' do |s|
    begin
      require 'rspec/core/rake_task'
      desc  'Run RSpec code examples with RCov'
      RSpec::Core::RakeTask.new 'spec:rcov' do |t|
        build_spec_task t, s.rspec
        t.rcov = true
        t.rcov_opts =  ['--failure-threshold', s.rspec.rcov.failure_threshold]
        # TODO: improve with more intelligent project layout guessing
        t.rcov_opts << %[-Ilib -Ispec --include "lib/" --exclude "gems/,spec/"]
      end
    rescue LoadError
    end
  end
  
  def self.build_spec_task task, rspec_settings
    t = task
    r = rspec_settings
    t.ruby_opts = r.ruby_opts if r.ruby_opts
  end
  
  class RCovSettings < Holder
    field 'failure_threshold'
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

