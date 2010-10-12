module Burke
  Settings.field(:gems) { self.gems = GemSettings.new }
  
  # Manually add 'install' to task management system
  TASK_DEFINITIONS['install'] = proc {}
  
  define_task 'gems' do |s|
    s.gems.individuals.each do |conf|
      GemTaskManager.add_task conf
    end
    
    desc "Build gem for this platform"
    task(:gem => GemTaskManager.task_for_this_platform.task_name)
    
    begin
      require 'rubygems/installer'
      GemTaskManager.install_task unless GemTaskManager::TASKS.empty?
    rescue LoadError
    end if Burke.task_enabled? 'install'
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
        conf.before_build.call spec unless conf.before_build.nil?
        builder = Gem::Builder.new(spec)
        builder.build
        verbose true do
          mkdir pkg_dir unless File.exists? pkg_dir
          mv conf.gem_file, File.join(pkg_dir, conf.gem_file)
        end
        conf.after_build.call spec unless conf.after_build.nil?
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
  
  class GemSettings < Holder
    field(:package_dir) { 'pkg' }
    
    attr_reader :individuals
    
    def add_platform plaf
      conf = IndividualGemSettings.new plaf
      @individuals ||= []
      @individuals << conf
      yield conf if block_given?
      conf
    end
    
    class IndividualGemSettings < Holder
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
      
      def before_build &block
        @before = block if block_given?
        @before
      end
      
      def after_build &block
        @after = block if block_given?
        @after
      end
    end
  end
end

