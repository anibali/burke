module Burke
  define_task 'release' do |s|
    begin
      require 'git'
    rescue LoadError
      raise "'git' gem is not available"
    end
    if s.key? 'version'
      raise "version is managed in an unknown way"
    end
    desc 'Release a new version of this project'
    task 'release' do |t|
      g = Git.open '.'
      st = g.status
      unless st.added.empty? and st.changed.empty? and st.deleted.empty?
        puts "Please commit changes with Git before releasing."
      else
        release_type = 0
        until (1..3).include? release_type
          puts "Please select type of release:"
          puts "1. Major"
          puts "2. Minor"
          puts "3. Patch"
          print "> "
          release_type = $stdin.gets.to_i
          puts
        end
        
        old_version = Gem::Version.new(s.version)
        segments = old_version.segments
        segments[release_type - 1] += 1
        new_version = Gem::Version.new(segments.join('.'))
        
        print "The VERSION file will be changed from containing '#{old_version}' "
        print "to '#{new_version}'. The changes will be commited to the Git "
        print "repository and tagged with 'v#{new_version}'."
        puts
        
        continue = nil
        until ['y', 'n'].include? continue
          print "Continue? [yn] "
          continue = $stdin.gets.strip.downcase
        end
        
        if continue == 'y'
          open 'VERSION', 'w' do |f|
            f.puts new_version.to_s
          end
          
          g.commit_all "Version bumped to #{new_version}"
          g.add_tag "v#{new_version}"
        end
      end
    end
  end
end

