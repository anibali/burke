module Burke
  define_task 'release' do |s|
    gem 'git'
    require 'git'
    
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
        
        case settings.docs.markup
        when 'rdoc'
          settings.docs.history_file ||= "History.rdoc"
        when 'markdown'
          settings.docs.history_file ||= "History.md"
        when 'textile'
          settings.docs.history_file ||= "History.textile"
        else
          settings.docs.history_file ||= "History.txt"
        end
        
        puts "Would you like the history file '#{settings.docs.history_file}' to be updated? [Y]es, [N]o"
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
        if update_changelog
          puts "A new entry will be made in the history file '#{settings.docs.history_file}'."
        end
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
            log_entries = nil
            begin
              log_entries = g.log.between("v#{old_version}", '.').to_a
            rescue
              log_entries = g.log.to_a
            end
            messages = log_entries.map {|c| c.message}.uniq
            str = ""
            time = Time.now
            date_str = "%.4d-%.2d-%.2d" % [time.year, time.month, time.day]
            heading = "Version #{new_version} / #{date_str}"
            case settings.docs.markup
            when 'rdoc'
              str << "=== #{heading}\n\n"
            when 'markdown'
              str << "### #{heading}\n\n"
            when 'textile'
              str << "h3. #{heading}\n\n"
            else
              str << "#{heading}\n\n"
            end
            str << messages.map {|m| "* " + m}.join("\n")
            
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

