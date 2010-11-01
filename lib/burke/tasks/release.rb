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
        until (1..4).include? release_type
          puts "Please select type of release:"
          puts "1. Major"
          puts "2. Minor"
          puts "3. Patch"
          puts "4. Enter version manually"
          print "> "
          release_type = $stdin.gets.to_i
          puts
        end
        
        old_version = Gem::Version.new(s.version)
        new_version = nil
        
        if release_type == 4
          until new_version
            print "Current version is #{old_version}. "
            puts "Please enter a new version number:"
            print "> "
            new_version = $stdin.gets
            if new_version.strip.empty?
              new_version = nil
            else
              new_version = Gem::Version.new(new_version)
            end
            puts
          end
        else
          segments = old_version.segments
          segments[release_type - 1] += 1
          new_version = Gem::Version.new(segments.join('.'))
        end
        
        puts "Would you like the history file (changelog) to be updated? [Y]es, [N]o"
        update_changelog = nil
        until %w[y n yes no].include? update_changelog
          print "> "
          update_changelog = $stdin.gets.strip.downcase
          puts
        end
        update_changelog = %w[yes y].include? update_changelog
        
        puts "The VERSION file will be changed from containing '#{old_version}' "
        puts "to '#{new_version}'. The changes will be commited to the Git "
        puts "repository and tagged with 'v#{new_version}'."
        puts "A new entry will be made in the history file (changelog)." if update_changelog
        puts
        
        continue = nil
        until %w[y n yes no].include? continue
          puts "Continue? [Y]es, [N]o"
          print "> "
          continue = $stdin.gets.strip.downcase
          puts
        end
        continue = %w[yes y].include? continue
        
        if continue
          if update_changelog
            messages = g.log.between("v#{old_version}", '.').map {|c| c.message}.uniq
            str = ""
            time = Time.now
            date_str = "%.4d-%.2d-%.2d" % [time.year, time.month, time.day]
            heading = "Version #{new_version} / #{date_str}"
            case settings.docs.markup
            when 'rdoc'
              str << "=== #{heading}\n\n"
              str << messages.map {|m| "* " + m}.join("\n")
              settings.docs.history_file ||= "History.rdoc"
            when 'markdown'
              str << "### #{heading}\n\n"
              str << messages.map {|m| "* " + m}.join("\n")
              settings.docs.history_file ||= "History.md"
            else
              str << "#{heading}\n\n"
              str << messages.map {|m| "* " + m}.join("\n")
              settings.docs.history_file ||= "History"
            end
            
            old_log = File.read(settings.docs.history_file) rescue ""
            new_log = [str, old_log].join("\n\n")
            open(settings.docs.history_file, 'w') do |f|
              f.write new_log
            end
          end
          
          open 'VERSION', 'w' do |f|
            f.puts new_version.to_s
          end
          
          g.commit_all "version bumped to #{new_version}"
          g.lib.send(:command, 'tag', ['-a', "v#{new_version}", '-m', "version #{new_version}"])
          
          puts "Version updated."
        else
          puts "Version not updated."
        end
      end
    end
  end
end

