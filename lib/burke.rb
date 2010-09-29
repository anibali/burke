require 'rubygems'
require 'rake'
require 'burke/holder'

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  TASK_DEFINITIONS = {}
  #TODO: remove this
  %w[yard rdoc gems install].each do |name|
    TASK_DEFINITIONS[name] = proc {}
  end
  
  class Settings < Holder ; end
  
  def self.define_task group_name, &block
    group_name = String(group_name)
    TASK_DEFINITIONS[group_name] = block
  end
end

require 'burke/tasks/rspec'
require 'burke/tasks/test'
require 'burke/tasks/clean'

module Burke
  @tasks = []
  
  class DocSettings < Holder
    field 'files'
    
    field 'readme_file' do
      find_file('readme{.*,}').freeze
    end
    
    field 'license_file' do
      find_file('{licen{c,s}e,copying}{.*,}').freeze
    end
    
    field 'markup' do
      case File.extname(readme_file).downcase
      when '.rdoc'
        'rdoc'
      when '.md', '.markdown'
        'markdown'
      when '.textile'
        'textile'
      end.freeze
    end
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
  
  class DependencySettings < Holder
  end
  
  class Settings < Holder
    fields *(Gem::Specification.attribute_names - [:dependencies, :development_dependencies])
    fields *%w[author docs test rspec gems clean clobber]
    
    field :dependencies do
      dependencies = (self.dependencies = DependencySettings.new)
      begin
        require 'bundler'
        bundler = Bundler.load
        deps = bundler.dependencies_for(:runtime)
        if deps.empty?
          deps = bundler.dependencies_for(:default)
        end
        deps.each do |d|
          dependencies[d.name] = d.requirement.to_s
        end
      rescue
      end
      dependencies
    end
    
    field :development_dependencies do
      dev_deps = (self.development_dependencies = DependencySettings.new)
      begin
        require 'bundler'
        Bundler.load.dependencies_for(:development).each do |d|
          dev_deps[d.name] = d.requirement.to_s
        end
      rescue
      end
      dev_deps
    end
    
    field(:rakefile_file) { find_file('rakefile').freeze }
    field(:version_file) { find_file('version{.*,}').freeze }
    
    field(:version) { File.read(version_file).strip.freeze if version_file }
    
    field :files do
      fs = Dir['{lib,spec,bin}/**/*']
      fs << docs.readme_file
      fs << docs.license_file
      fs << version_file
      fs << rakefile_file
      fs.compact.freeze
    end
    
    def initialize *args
      super
      self.docs = DocSettings.new
      self.gems = GemSettings.new
    end
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
  
  class << self
    def enable_all opts={}
      @enabled_tasks = TASK_DEFINITIONS.keys
      disable opts[:except] if opts[:except]
    end
    
    def enable *args
      @enabled_tasks.concat([*args].map {|t| t.to_sym})
      @enabled_tasks.uniq!
    end
    
    def disable *args
      dis = [*args].map {|t| t.to_sym}
      @enabled_tasks.reject! {|t| dis.include? t}
    end
    
    def setup &block
      @settings = Settings.new
      
      @settings.instance_exec @settings, &block
      
      if task_enabled? :gems and GemTaskManager::TASKS.empty?
        @settings.gems.platform 'ruby'
      end
      
      generate_tasks
      
      return @settings
    end
    
    def task_enabled? name
      @enabled_tasks.include? String(name)
    end
    
    def generate_tasks
      TASK_DEFINITIONS.each do |group_name, block|
        if task_enabled? group_name
          block.call @settings
        end
      end
      
      unless @settings.docs.files
        d = @settings.docs
        fl = FileList.new
        fl.include "lib/**/*.rb"
        fl.include d.readme_file if d.readme_file
        fl.include d.license_file if d.license_file
        d.files = fl.to_a
      end
      
      begin
        require 'yard'
        opts = []
        d = @settings.docs
        opts << "--title" << "#{@settings.name} #{@settings.version}"
        opts << "--readme" << d.readme_file if d.readme_file
        opts << "--markup" << d.markup if d.markup
        extra_files = [d.license_file].compact
        opts << "--files" << extra_files.join(',') unless extra_files.empty?
        YARD::Rake::YardocTask.new 'yard' do |t|
          t.options = opts
        end
      rescue LoadError
      end if task_enabled? :yard
      
      begin
        require 'rake/rdoctask'
        d = @settings.docs
        Rake::RDocTask.new 'rdoc' do |r|
          r.rdoc_files.include d.files
          r.title = "#{@settings.name} #{@settings.version}"
          r.main = d.readme_file if d.readme_file
        end
      rescue LoadError
      end if task_enabled? :rdoc
      
      if @settings.has_rdoc
        d = @settings.docs
        (@settings.extra_rdoc_files ||= []).concat d.files
        opts = []
        opts << "--title" << "#{@settings.name} #{@settings.version}"
        opts << "--main" << d.readme_file if d.readme_file
        @settings.rdoc_options ||= opts
      end
      
      begin
        settings.gems.individuals.each do |conf|
          GemTaskManager.add_task conf
        end
        
        if name
          desc "Build gem for this platform"
          task(:gem => GemTaskManager.task_for_this_platform.task_name)
        end
      rescue LoadError
      end if task_enabled? :gems
      
      begin
        require 'rubygems/installer'
        GemTaskManager.install_task unless GemTaskManager::TASKS.empty?
      rescue LoadError
      end if task_enabled? :install
    end
    
    def base_gemspec
      if @base_gemspec.nil?
        @base_gemspec = Gem::Specification.new
        
        attrs = Gem::Specification.attribute_names
        attrs -= [:dependencies, :development_dependencies]
        attrs += [:author]
        
        attrs.each do |attr|
          value = @settings.send(attr)
          @base_gemspec.send("#{attr}=", value) if value
        end
        
        @settings.dependencies.each do |gem, requirements|
          @base_gemspec.add_dependency gem.to_s, *requirements
        end
        
        @settings.development_dependencies.each do |gem, requirements|
          @base_gemspec.add_development_dependency gem.to_s, *requirements
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

