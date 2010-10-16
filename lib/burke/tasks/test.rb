module Burke
  Settings.field(:test) { self.test = TestSettings.new }
  
  define_task 'test' do |s|
    if @settings.test.files.empty?
      raise "project doesn't seem to contain test files"
    end
    require 'rake/testtask'
    Rake::TestTask.new do |t|
      t.test_files = s.test.files
    end
  end
  
  class TestSettings < Holder
    field 'files' do
      Dir['test/**/{*_{test,tc},{test,tc}_*}.rb'].freeze
    end
  end
end

