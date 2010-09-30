module Burke
  define_task 'rdoc' do |s|
    begin
      require 'rake/rdoctask'
      d = s.docs
      Rake::RDocTask.new 'rdoc' do |r|
        r.rdoc_files.include d.files
        r.title = d.title
        r.main = d.readme_file if d.readme_file
      end
    rescue LoadError
    end
  end
end

