module Burke
  Settings.field(:clean) { self.clean = [] }
  Settings.field(:clobber) { self.clobber = [] }
  
  define_task 'clean' do |s|
    require 'rake/clean'
    CLEAN.include(*s.clean) if s.clean
  end
  
  define_task 'clobber' do |s|
    require 'rake/clean'
    CLOBBER.include(*s.clobber) if s.clobber
  end
end

