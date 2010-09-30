module Burke
  define_task 'yard' do |s|
    begin
      require 'yard'
      opts = []
      d = s.docs
      opts << "--title" << d.title
      opts << "--readme" << d.readme_file if d.readme_file
      opts << "--markup" << d.markup if d.markup
      opts << "--files" << d.extra_files.join(',') unless d.extra_files.empty?
      YARD::Rake::YardocTask.new 'yard' do |t|
        t.options = opts
      end
    rescue LoadError
    end
  end
end

