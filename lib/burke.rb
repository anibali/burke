require 'rubygems'
require 'rake'
require 'hashie'

class Smash < Hashie::Mash
  def initialize *args
    super
    @read_filters = {}
    @write_filters = {}
  end
  
  def method_missing name, *args
    key = convert_key(name)
    if key? key or @read_filters.key? key
      value = self[key]
      yield value if block_given?
      value
    else
      super
    end
  end
  
  def [](key)
    filter = @read_filters[convert_key(key)]
    value = super(key)
    filter.nil? ? value : filter[value]
  end
  
  def []=(key, value)
    filter = @write_filters[convert_key(key)]
    value = filter[value] if filter
    super(key, value)
  end
  
  def read_filter key, &block
    key = convert_key(key)
    @read_filters[key] = block
  end
  
  def write_filter key, &block
    @write_filters[convert_key(key)] = block
  end
end

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  ALL_TASKS = [:clean, :yard, :rdoc, :rspec, :rspec_rcov, :gems, :install, :test]
  @tasks = []
  
  class << self
    def enable_all opts={}
      @tasks = ALL_TASKS.dup
      disable opts[:except] if opts[:except]
    end
    
    def enable *args
      @tasks.concat([*args].map {|t| t.to_sym})
      @tasks.uniq!
    end
    
    def disable *args
      dis = [*args].map {|t| t.to_sym}
      @tasks.reject! {|t| dis.include? t}
    end
    
    def setup
      @settings = create_settings
      
      yield @settings
      
      if @tasks.include? :gems and GemTaskManager::TASKS.empty?
        @settings.gems.platform 'ruby'
      end
      
      generate_tasks
      
      return @settings
    end
    
    def generate_tasks
      begin
        require 'rake/clean'
        CLEAN.include(*@settings.clean) if @settings.clean
        CLOBBER.include(*@settings.clobber) if @settings.clobber
      rescue LoadError
      end if @tasks.include? :clean
      
      unless @settings.docs.files
        d = @settings.docs
        fl = FileList.new
        fl.include "lib/**/*.rb"
        fl.include d.readme if d.readme
        fl.include d.license if d.license
        d.files = fl.to_a
      end
      
      begin
        require 'yard'
        opts = []
        d = @settings.docs
        opts << "--title" << "#{@settings.name} #{@settings.version}"
        opts << "--readme" << d.readme if d.readme
        opts << "--markup" << d.markup if d.markup
        extra_files = [d.license].compact
        opts << "--files" << extra_files.join(',') unless extra_files.empty?
        YARD::Rake::YardocTask.new 'yard' do |t|
          t.options = opts
        end
      rescue LoadError
      end if @tasks.include? :yard
      
      begin
        require 'rake/rdoctask'
        d = @settings.docs
        Rake::RDocTask.new 'rdoc' do |r|
          r.rdoc_files.include d.files
          r.title = "#{@settings.name} #{@settings.version}"
          r.main = d.readme if d.readme
        end
      rescue LoadError
      end if @tasks.include? :rdoc
      
      if @settings.has_rdoc
        d = @settings.docs
        (@settings.extra_rdoc_files ||= []).concat d.files
        opts = []
        opts << "--title" << "#{@settings.name} #{@settings.version}"
        opts << "--main" << d.readme if d.readme
        @settings.rdoc_options ||= opts
      end
      
      begin
        require 'spec/rake/spectask'
        r = @settings.rspec
        opts = []
        if r.options_file
          opts << "--options" << r.options_file
        else
          opts << "--colour" if r.color
          opts << "--format" << r.format if r.format
        end
        Spec::Rake::SpecTask.new 'spec' do |t|
          t.spec_files = r.spec_files
          t.spec_opts = opts
          t.ruby_opts = r.ruby_opts if r.ruby_opts
        end
        
        begin
          require 'spec/rake/verify_rcov'
          
          desc "Run specs with RCov"
          Spec::Rake::SpecTask.new('spec:rcov') do |t|
            t.spec_files = r.spec_files
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
        end if @tasks.include? :rspec_rcov
      rescue LoadError
      end if @tasks.include? :rspec and !@settings.rspec.spec_files.empty?
      
      begin
        require 'rake/testtask'
        Rake::TestTask.new do |t|
          t.test_files = @settings.test.test_files
        end
      rescue LoadError
      end if @tasks.include? :test and !@settings.test.test_files.empty?
      
      begin
        settings.gems.individuals.each do |conf|
          GemTaskManager.add_task conf
        end
        
        if name
          desc "Build gem for this platform"
          task(:gem => GemTaskManager.task_for_this_platform.task_name)
        end
      rescue LoadError
      end if @tasks.include? :gems
      
      begin
        require 'rubygems/installer'
        GemTaskManager.install_task unless GemTaskManager::TASKS.empty?
      rescue LoadError
      end if @tasks.include? :install
    end
    
    def base_gemspec
      if @base_gemspec.nil?
        @base_gemspec = Gem::Specification.new
        
        attrs = Gem::Specification.attribute_names
        attrs -= [:dependencies]
        attrs += [:author]
        
        attrs.each do |attr|
          value = @settings.send(attr)
          @base_gemspec.send("#{attr}=", value) if value
        end
        
        @settings.dependencies.each do |gem, version|
          @base_gemspec.add_dependency gem.to_s, version
        end
      end
      
      @base_gemspec
    end
    
    def settings
      @settings
    end
    
    def create_settings
      # TODO: put default values in getter filters
      s = Smash.new
      s.dependencies!
      s.docs!
      s.rspec!.rcov!
      s.test!
      s.gems = GemSettings.new
      s.clean = []
      s.clobber = []
      
      s.read_filter :files do |v|
        if v.nil?
          v = Dir['{lib,spec,bin}/**/*']
          v << s.docs.readme_file
          v << s.docs.license_file
          v << s.version_file
          v << s.rakefile_file
          v.compact.freeze
        else
          v
        end
      end
      
      s.read_filter :rakefile_file do |v|
        v or find_file('rakefile').freeze
      end
      
      s.read_filter :version_file do |v|
        v or find_file('version{.*,}').freeze
      end
      
      s.read_filter :version do |v|
        if v.nil? and s.version_file
          File.read(s.version_file).strip.freeze
        else
          v
        end
      end
      
      s.docs.read_filter :readme_file do |v|
        v or find_file('readme{.*,}').freeze
      end
      s.docs.read_filter(:readme) { s.docs.readme_file }
      s.docs.write_filter(:readme) { |v| s.docs.readme_file = v }
      
      s.docs.read_filter :license_file do |v|
        v or find_file('{licen{c,s}e,copying}{.*,}').freeze
      end
      s.docs.read_filter(:license) { s.docs.license_file }
      s.docs.write_filter(:license) { |v| s.docs.license_file = v }
      
      s.docs.read_filter :markup do |v|
        readme = s.docs.readme
        if v.nil? and readme
          case File.extname(readme).downcase
          when '.rdoc'
            'rdoc'
          when '.md', '.markdown'
            'markdown'
          when '.textile'
            'textile'
          end.freeze
        else
          v
        end
      end
      
      s.test.read_filter :test_files do |v|
        v or Dir['test/**/{*_{test,tc},{test,tc}_*}.rb'].freeze
      end
      
      s.rspec.read_filter :options_file do |v|
        v or find_file('{{spec/,}{spec.opts,.specopts}}').freeze
      end
      
      s.rspec.read_filter :color do |v|
        v.nil? ? true : v
      end
      
      s.rspec.read_filter :spec_files do |v|
        v or Dir['spec/**/*_spec.rb'].freeze
      end
      
      s.rspec.write_filter(:ruby_opts) { |v| [*v] }
      
      return s
    end
    
    private
    def readable_file? file
      File.readable? file and File.file? file
    end
    
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| readable_file? f }
    end
  end
  
  class GemTaskManager
    TASKS = {}
    
    def self.add_task conf
      spec = conf.gemspec
      name = "gem:#{spec.platform}"
      pkg_dir = Burke.settings.gems.package_dir
      
      if TASKS.empty?
        desc "Build gems for all targets"
      end
      task :gems => name
      
      unless ::Rake.application.last_comment
        desc "Build gem for target '#{spec.platform}'"
      end
      
      task(name) do
        conf.before.call spec unless conf.before.nil?
        builder = Gem::Builder.new(spec)
        builder.build
        verbose true do
          mkdir pkg_dir unless File.exists? pkg_dir
          mv conf.gem_file, File.join(pkg_dir, conf.gem_file)
        end
        conf.after.call spec unless conf.after.nil?
      end
      
      TASKS[spec.platform.to_s] = conf
    end
    
    def self.has_task? platform
      TASKS.has_key? platform
    end
    
    def self.task_for_this_platform
      platform = Gem::Platform.new(RUBY_PLATFORM).to_s
      name = nil
      
      if GemTaskManager.has_task? platform
        name = platform
      elsif GemTaskManager.has_task? 'ruby'
        name = "ruby"
      end
      
      TASKS[name]
    end
    
    def self.install_task
      t = task_for_this_platform
      
      desc "Install gem for this platform"
      task 'install' => [t.task_name] do
        Gem::Installer.new(File.join(t.package_dir, t.gem_file)).install
      end
    end
  end
  
  class GemSettings
    attr_accessor :package_dir, :individuals
    
    def initialize
      @package_dir = 'pkg'
    end
    
    def platform plaf
      conf = IndividualGemSettings.new plaf
      @individuals ||= []
      @individuals << conf
      yield conf if block_given?
      conf
    end
    
    class IndividualGemSettings
      attr_reader :platform
      
      def initialize plaf
        @platform = Gem::Platform.new plaf
      end
      
      def gemspec
        spec = Burke.base_gemspec.dup
        spec.platform = @platform
        spec
      end
      
      def gem_file
        "#{gemspec.full_name}.gem"
      end
      
      def task_name
        "gem:#{platform}"
      end
      
      def package_dir
        Burke.settings.gems.package_dir
      end
      
      def before &block
        @before = block if block_given?
        @before
      end
      
      def after &block
        @after = block if block_given?
        @after
      end
    end
  end
end

