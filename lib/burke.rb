require 'rubygems'
require 'rubygems/installer'
require 'rake'
require 'rake/tasklib'
require 'mash'

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  @tasks = []
  
  class << self
    def enable_all opts={}
      @tasks = %w[clean yard rdoc rspec rspec_rcov gems install].map {|t| t.to_sym}
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
      @settings = Mash[
        :dependencies => Mash[],
        :docs => Mash[],
        :rspec => Mash[:rcov => Mash[]],
        :gems => GemSettings.new,
        :clean => [],
        :clobber => [],
      ]
      
      @settings.files = Dir.glob('{lib,spec}/**/*')
      %w[Rakefile COPYING LICENSE].each do |file|
        @settings.files << file if File.exists?(file)
      end
      
      project_files = Dir['*'].reject! {|f| File.directory? f or !File.readable? f}
      
      version_file = 'VERSION'
      if File.readable?(version_file)
        @settings.version = File.read(version_file).strip
        @settings.files << version_file
      end
      
      license_file = nil
      project_files.each do |f|
        if %w[license licence copying].include? f.downcase.split('.').first
          license_file = f
        end
      end
      
      if license_file
        @settings.docs.license = license_file
        @settings.files << license_file
      end
      
      readme_file = nil
      project_files.each do |f|
        if f.downcase =~ /readme[\..*]?/
          readme_file = f if readme_file.nil? or f.length < readme_file.length
        end
      end
      
      if readme_file
        @settings.docs.readme = File.basename readme_file
        @settings.files << readme_file
        @settings.docs.markup = case File.extname(readme_file).downcase
        when '.rdoc'
          'rdoc'
        when '.md'
          'markdown'
        when '.textile'
          'textile'
        end
      end
      
      @settings.rspec.spec_files = Dir['spec/**/*_spec.rb']
      @settings.rspec.color = true
      
      yield @settings
      
      begin
        require 'rake/clean'
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
        opts << "--colour" if r.color
        opts << "--format" << r.format if r.format
        Spec::Rake::SpecTask.new 'spec' do |t|
          t.spec_files = r.spec_files
          t.spec_opts = opts
        end unless r.empty?
        
        begin
          require 'spec/rake/verify_rcov'
          
          desc "Run specs with RCov"
          Spec::Rake::SpecTask.new('spec:rcov') do |t|
            t.spec_files = r.spec_files
            t.spec_opts = opts
            t.rcov = true
            t.rcov_opts = ['--exclude', 'spec']
          end

          RCov::VerifyTask.new('spec:rcov:verify' => 'spec:rcov') do |t|
            t.threshold = r.rcov.threshold
            t.index_html = 'coverage/index.html'
          end if r.rcov.threshold
        rescue LoadError
        end if @tasks.include? :rspec_rcov
      rescue LoadError
      end if @tasks.include? :rspec
      
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
      
      if @tasks.include? :install
        GemTaskManager.install_task unless GemTaskManager::TASKS.empty?
      end
      
      @settings
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

