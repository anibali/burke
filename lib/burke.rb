require 'rubygems'
require 'rubygems/installer'
require 'rake'
require 'rake/tasklib'
require 'mash'

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  
  class << self
    def enable_all opts={}
      @tasks = %w[clean yard rdoc rspec gems install].map {|t| t.to_sym}
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
        :rspec => Mash[],
        :gems => GemSettings.new,
      ]
      
      version_file = File.join(rakefile_dir, 'VERSION')
      @settings[:version] = File.read(version_file).strip if File.readable?(version_file)
      
      yield @settings
      
      begin
        require 'rake/clean'
        CLOBBER.include(*@settings.clobber) if @settings.clobber
      rescue LoadError
      end if @tasks.include? :clean
      
      begin
        require 'yard'
        opts = []
        d = @settings.docs
        opts << "--title" << "#{d.name} #{d.version}"
        opts << "--readme" << d.readme if d.readme
        opts << "--markup" << d.markup if d.markup
        YARD::Rake::YardocTask.new 'yard' do |t|
          t.options = opts
        end
      rescue LoadError
      end if @tasks.include? :yard
      
      begin
        require 'rake/rdoctask'
        d = @settings.docs
        Rake::RDocTask.new 'rdoc' do |r|
          if d.readme
            r.main = d.readme
            r.rdoc_files.include d.readme, "lib/**/*.rb"
          end
          r.title = "#{d.name} #{d.version}"
        end
      rescue LoadError
      end if @tasks.include? :rdoc
      
      begin
        require 'spec/rake/spectask'
        r = @settings.rspec
        opts = []
        opts << "--colour" if r.color
        Spec::Rake::SpecTask.new 'spec' do |s|
          s.spec_files = r.spec_files
          s.spec_opts = opts
        end unless r.empty?
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
        
        Gem::Specification.attribute_names.each do |attr|
          value = @settings.send(attr)
          @base_gemspec.send("#{attr}=", value) if value
        end
        
        @settings.dependencies.each do |gem, version|
          @base_gemspec.add_dependency gem.to_s, version
        end
      end
      
      @base_gemspec
    end
    
    def rakefile_dir
      caller.each do |cl|
        if %r{^(.*):\d+(?::in )?$} =~ cl
          f = $1
          return File.dirname(f) if f != __FILE__
        end
      end
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
      
      TASKS[spec.platform] = conf
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

