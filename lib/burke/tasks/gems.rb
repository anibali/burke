module Burke
  Settings.field(:gems) { self.gems = GlobalGemSettings.new }
  
  define_task 'gems' do |s|
    s.gems.individuals.each do |conf|
      GemTaskManager.add_task conf
    end
    
    desc "Build gem for this platform"
    task(:gem => GemTaskManager.task_for_this_platform.task_name)
  end
  
  define_task 'install' => 'gems' do |s|
    require 'rubygems/installer'
    unless GemTaskManager::TASKS.empty?
      t = GemTaskManager.task_for_this_platform
      
      desc "Install gem for this platform"
      task 'install' => [t.task_name] do
        Gem::Installer.new(File.join(t.package_dir, t.gem_file)).install
      end
    end
  end
  
  class GlobalGemSettings < Holder
    field(:package_dir) { 'pkg' }
    
    attr_reader :individuals
    
    def add_platform plaf
      conf = IndividualGemSettings.new plaf
      @individuals ||= []
      @individuals << conf
      yield conf if block_given?
      conf
    end
  end
  
  class IndividualGemSettings < Holder
    attr_reader :platform
    
    field(:gemspec) do
      spec = Burke.base_gemspec.dup
      spec.platform = @platform
      spec
    end
    field(:gem_file) { "#{gemspec.full_name}.gem" }
    field(:package_dir) { Burke.settings.gems.package_dir }
    
    def initialize plaf
      super
      @platform = Gem::Platform.new plaf
    end
    
    def task_name
      "gem:#{platform}"
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
  
  class GemTaskManager
    TASKS = {}
    
    def self.add_task conf
      gemspec = conf.gemspec
      name = conf.task_name
      pkg_dir = conf.package_dir
      
      unless Rake::Task.tasks.find {|t| t.name == 'gems'}
        desc "Build gems for all targets"
      end
      task(:gems => name)
      
      unless Rake::Task.tasks.find {|t| t.name == name}
        desc "Build gem for target '#{gemspec.platform}'"
      end
      task(name) do |t|
        conf.before_build.call gemspec unless conf.before_build.nil?
        builder = Gem::Builder.new(gemspec)
        builder.build
        verbose true do
          mkdir pkg_dir unless File.exists? pkg_dir
          mv conf.gem_file, File.join(pkg_dir, conf.gem_file)
        end
        conf.after_build.call gemspec unless conf.after_build.nil?
      end
      
      TASKS[gemspec.platform.to_s] = conf
    end
    
    def self.task_for_this_platform
      platform = Gem::Platform.new(RUBY_PLATFORM).to_s
      name = nil
      
      if TASKS.key? platform
        name = platform
      elsif TASKS.key? 'ruby'
        name = "ruby"
      end
      
      TASKS[name]
    end
  end
end

