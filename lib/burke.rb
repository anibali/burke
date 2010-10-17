require 'rubygems'
require 'rake'
require 'burke/holder'

module Burke
  VERSION = File.read(File.join(File.dirname(File.dirname(__FILE__)), 'VERSION'))
  
  class Settings < Holder ; end
  
  class TaskDefinition
    ALL = {}
    
    attr_reader :name, :block, :prerequisites
    
    def initialize *args, &block
      a1, a2 = *args
      name = nil
      prereqs = nil
      if a1.is_a? Hash
        name, prereqs = *a1.entries[0]
      else
        name, prereqs = a1, a2
      end
      @name = String(name)
      @prerequisites = [*prereqs].compact.map {|e| String(e)}
      @block = block
      ALL[@name] = self
    end
    
    def execute(s)
      unless @executed
        execute_prerequisites(s)
        @block.call(s)
        @executed = true
      end
    end
    
    def execute_prerequisites(s)
      @prerequisites.each do |prereq|
        ALL[prereq].execute(s)
      end
    end
  end
  
  def self.define_task *args, &block
    TaskDefinition.new *args, &block
  end
end

require 'burke/tasks/rspec'
require 'burke/tasks/test'
require 'burke/tasks/clean'
require 'burke/tasks/docs'
require 'burke/tasks/rdoc'
require 'burke/tasks/yard'
require 'burke/tasks/gems'
require 'burke/tasks/release'

module Burke
  @tasks = []
  @enabled_tasks = TaskDefinition::ALL.keys
  
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
    def enable_all opts={}
      @enabled_tasks = TaskDefinition::ALL.keys
      disable *opts[:except] if opts[:except]
    end
    
    def disable_all opts={}
      @enabled_tasks = []
      enable *opts[:except] if opts[:except]
    end
    
    def enable *args
      @enabled_tasks.concat([*args].map {|t| String(t)})
      @enabled_tasks.uniq!
    end
    
    def disable *args
      dis = [*args].map {|t| String(t)}
      @enabled_tasks.reject! {|t| dis.include? t}
    end
    
    def settings
      @settings ||= Settings.new
    end
    
    def setup &block
      settings.instance_exec settings, &block
      
      if task_enabled? :gems and GemTaskManager::TASKS.empty?
        settings.gems.add_platform 'ruby'
      end
      
      enabled = []
      disabled = []
      
      # Generate tasks
      TaskDefinition::ALL.each do |name, td|
        if task_enabled? name
          begin
            td.execute(settings)
            enabled << [name, nil]
          rescue Exception => ex
            disabled << [name, ex.message]
          end
        else
          disabled << [name, "disabled by project developer"]
        end
      end
      
      desc 'List enabled and disabled tasks'
      task 'tasks' do
        puts '+---------+'
        puts '| Enabled |'
        puts '+---------+'
        width = enabled.map {|a| a[0].length}.sort.last
        enabled.sort_by {|a| a[0]}.each do |name, reason|
          line = "+ #{name.ljust(width)}"
          line << " (#{reason})" if reason
          puts line
        end
        puts
        puts '+----------+'
        puts '| Disabled |'
        puts '+----------+'
        width = disabled.map {|a| a[0].length}.sort.last
        disabled.sort_by {|a| a[0]}.each do |name, reason|
          line = "- #{name.ljust(width)}"
          line << " (#{reason})" if reason
          puts line
        end
      end
      
      return settings
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
          value = settings.send(attr)
          @base_gemspec.send("#{attr}=", value) if value
        end
        
        settings.dependencies.each do |gem, requirements|
          @base_gemspec.add_dependency gem.to_s, *requirements
        end
        
        settings.development_dependencies.each do |gem, requirements|
          @base_gemspec.add_development_dependency gem.to_s, *requirements
        end
      end
      
      @base_gemspec
    end
  end
end

