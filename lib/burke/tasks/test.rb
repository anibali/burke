module Burke
  Settings.field(:test) { self.test = TestSettings.new }
  
  define_task 'test' do |s|
    begin
      require 'rake/testtask'
      Rake::TestTask.new do |t|
        t.test_files = s.test.files
      end
    rescue LoadError
    end unless @settings.test.files.empty?
  end
  
  class TestSettings < Holder
    field 'files' do
      Dir['test/**/{*_{test,tc},{test,tc}_*}.rb'].freeze
    end
  end
end

