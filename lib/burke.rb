require 'rubygems'
require 'rubygems/installer'
require 'rake'
require 'rake/tasklib'

desc "Build gems for all targets"
task :gems

module Burke
  VERSION = '0.1.0'
  
  class << self
    def base_spec
      @base_spec ||= Gem::Specification.new
      yield @base_spec if block_given?
      @base_spec
    end
    
    def package_task *args, &block
      Rake::GemPackageTask.new *args, &block
    end
    
    def install_task *args, &block
      Rake::GemInstallTask.new *args, &block
    end
    
    def yard_task *args, &block
      begin
        require 'yard'
        YARD::Rake::YardocTask.new *args, &block
      rescue LoadError
        puts "Couldn't load Yard: generation of Yard docs is disabled"
      end
    end
    
    def spec_task *args, &block
      begin
        require 'spec/rake/spectask'
        Spec::Rake::SpecTask.new *args, &block
      rescue LoadError
        puts "Couldn't load RSpec: running of RSpec examples is disabled"
      end
    end
  end
  
  module Rake
    class GemPackageTask < ::Rake::TaskLib
      attr_reader :spec, :name
      
      TASKS = {}
      
      @@package_dir = 'pkg'
      
      def initialize plaf=Gem::Platform::RUBY
        @spec = Burke.base_spec.dup
        @spec.platform = Gem::Platform.new plaf
        @name = "gem:#{@spec.platform}"
        yield self if block_given?
        define
      end
      
      def self.package_dir= path
        @@package_dir = path
      end
      
      def self.package_dir
        @@package_dir
      end
      
      def before &block
        @before = block
      end
      
      def extend_spec &block
        @extend_spec = block
      end
      
      def after &block
        @after = block
      end
      
      def gem_file
        "#{spec.full_name}.gem"
      end
      
      private
      def define
        task :gems => name
        
        unless ::Rake.application.last_comment
          desc "Build gem for target '#{@spec.platform}'"
        end
        task(name) { run_task }
        TASKS[name] = self
        
        if @spec.platform == Gem::Platform::RUBY
          desc "Build gem for target '#{@spec.platform}'"
          task(:gem) { run_task }
        end
        
        self
      end
      
      def run_task
        @before.call unless @before.nil?
        @extend_spec.call spec unless @extend_spec.nil?
        builder = Gem::Builder.new(@spec)
        builder.build
        verbose true do
          mkdir @@package_dir unless File.exists? @@package_dir
          mv gem_file, File.join(@@package_dir, gem_file)
        end
        @after.call unless @after.nil?
      end
    end
    
    class GemInstallTask < ::Rake::TaskLib
      attr_reader :name
      
      def initialize
        @name = "install"
        define
      end
      
      private
      def define
        platform = Gem::Platform.new(RUBY_PLATFORM).to_s
        t = nil
        dep = nil
        unless t = GemPackageTask::TASKS["gem:#{platform}"]
          t = GemPackageTask::TASKS["gem:ruby"]
        end
        
        desc "Build and install gem for this platform"
        task name => [t.name] do
          Gem::Installer.new(File.join(GemPackageTask.package_dir, t.gem_file)).install
        end
        
        self
      end
    end
  end
end

