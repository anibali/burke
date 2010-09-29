module Burke
  Settings.field(:clean) { self.clean = [] }
  Settings.field(:clobber) { self.clobber = [] }
  
  define_task 'clean' do |s|
    begin
      require 'rake/clean'
      CLEAN.include(*s.clean) if s.clean
    rescue LoadError
    end
  end
  
  define_task 'clobber' do |s|
    begin
      require 'rake/clean'
      CLOBBER.include(*s.clobber) if s.clobber
    rescue LoadError
    end
  end
end

