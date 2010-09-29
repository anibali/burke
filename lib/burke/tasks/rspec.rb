module Burke
  Settings.field(:rspec) { self.rspec = RSpecSettings.new }
  
  define_task 'rspec' do |s|
    begin
      require 'spec/rake/spectask'
      
      r = s.rspec
      opts = build_rspec_opts r
      
      Spec::Rake::SpecTask.new 'spec' do |t|
        t.spec_files = r.files
        t.spec_opts = opts
        t.ruby_opts = r.ruby_opts if r.ruby_opts
      end
    rescue LoadError
    end unless s.rspec.files.empty?
  end
  
  define_task 'rspec:rcov' do |s|
    begin
      require 'spec/rake/spectask'
      require 'rcov'
      require 'spec/rake/verify_rcov'
      
      r = s.rspec
      opts = build_rspec_opts r
      
      desc "Run specs with RCov"
      Spec::Rake::SpecTask.new('spec:rcov') do |t|
        t.spec_files = r.files
        t.spec_opts = opts
        t.rcov = true
        t.rcov_opts = ['--exclude', 'spec']
      end
      
      desc "Run specs with RCov and verify code coverage"
      RCov::VerifyTask.new('spec:rcov:verify' => 'spec:rcov') do |t|
        t.threshold = r.rcov.threshold
        t.index_html = 'coverage/index.html'
      end if r.rcov.threshold
    rescue LoadError
    end if task_enabled? :rspec
  end
  
  def self.build_rspec_opts r
    opts = []
    if r.options_file
      opts << "--options" << r.options_file
    else
      opts << "--colour" if r.color
      opts << "--format" << r.format if r.format
    end
    opts
  end
  
  class RCovSettings < Holder
    field 'threshold'
  end
  
  class RSpecSettings < Holder
    field 'files' do
      Dir['spec/**/*_spec.rb'].freeze
    end
    
    field 'options_file' do
      find_file('{{spec/,}{spec.opts,.specopts}}').freeze
    end
    
    field 'color' do
      true
    end
    
    field 'format' do
      'progress'
    end
    
    field 'ruby_opts'
    field('rcov') { self.rcov = RCovSettings.new }
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
end

