require 'rubygems'
require 'rake'
require 'burke/holder'

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  TASK_DEFINITIONS = {}
  
  class Settings < Holder ; end
  
  def self.define_task group_name, &block
    group_name = String(group_name)
    TASK_DEFINITIONS[group_name] = block
  end
end

require 'burke/tasks/rspec'
require 'burke/tasks/test'
require 'burke/tasks/clean'
require 'burke/tasks/docs'
require 'burke/tasks/rdoc'
require 'burke/tasks/yard'
require 'burke/tasks/gems'

module Burke
  @tasks = []
  
  class DependencySettings < Holder
    def self.field_exists? name ; true ; end
  end
  
  class Settings < Holder
    fields *(Gem::Specification.attribute_names - [:dependencies, :development_dependencies])
    fields *%w[author gems]
    
    field(:has_rdoc) { Burke.task_enabled? :rdoc }
    
    field :rdoc_options do
      opts = []
      opts << "--title" << docs.title
      opts << "--main" << docs.readme_file if docs.readme_file
      opts.freeze
    end
    
    field :extra_rdoc_files do
      docs.extra_files
    end
    
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
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
  
  class << self
    attr_reader :settings
    
    def enable_all opts={}
      @enabled_tasks = TASK_DEFINITIONS.keys
      disable *opts[:except] if opts[:except]
    end
    
    def enable *args
      @enabled_tasks.concat([*args].map {|t| String(t)})
      @enabled_tasks.uniq!
    end
    
    def disable *args
      dis = [*args].map {|t| String(t)}
      @enabled_tasks.reject! {|t| dis.include? t}
    end
    
    def setup &block
      @settings = Settings.new
      
      @settings.instance_exec @settings, &block
      
      if task_enabled? :gems and GemTaskManager::TASKS.empty?
        @settings.gems.add_platform 'ruby'
      end
      
      # Generate tasks
      TASK_DEFINITIONS.each do |group_name, block|
        if task_enabled? group_name
          block.call @settings
        end
      end
      
      return @settings
    end
    
    def task_enabled? name
      @enabled_tasks.include? String(name)
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
  end
end

