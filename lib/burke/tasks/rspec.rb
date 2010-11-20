module Burke
  Settings.field(:rspec) { self.rspec = RSpecSettings.new }
  
  define_task 'spec' do |s|
    gem 'rspec-core', '~> 2'
    require 'rspec/core/rake_task'
    
    RSpec::Core::RakeTask.new 'spec' do |t|
      build_spec_task t, s.rspec
    end
  end
  
  define_task 'spec:rcov' do |s|
    gem 'rspec-core', '~> 2'
    gem 'rcov'
    require 'rspec/core/rake_task'
    
    desc "Run RSpec code examples and generate full RCov report"
    RSpec::Core::RakeTask.new('spec:rcov') do |t|
      build_spec_task t, s.rspec
      require 'shellwords'
      t.rcov = true
      t.rcov_opts = [
        "-I#{%w[lib spec].map {|e| File.expand_path(e).shellescape }.join ':'}",
        '--exclude', "'spec/,#{s.rakefile_file}'",
      ]
    end
  end
  
  define_task 'spec:rcov:verify' do |s|
    gem 'rspec-core', '~> 2'
    gem 'rcov'
    require 'rspec/core/rake_task'
    
    desc "Run RSpec code examples and verify RCov percentage"
    RSpec::Core::RakeTask.new('spec:rcov:verify') do |t|
      build_spec_task t, s.rspec
      require 'shellwords'
      t.rcov = true
      t.rcov_opts = [
        '--failure-threshold', s.rspec.rcov.failure_threshold,
        "-I#{%w[lib spec].map {|e| File.expand_path(e).shellescape }.join ':'}",
        '--exclude', "'spec/,#{s.rakefile_file}'",
        '--no-html'
      ]
    end
  end
  
  def self.build_spec_task task, rspec_settings
    t = task
    r = rspec_settings
    
    if Dir.glob(r.pattern).empty?
      raise "project does not appear to have any RSpec examples"
    end
    
    t.pattern = r.pattern
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
    
    field('pattern') { "spec/**/*_spec.rb" }
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
end

