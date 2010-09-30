module Burke
  Settings.field(:docs) { self.docs = DocSettings.new }
  
  class DocSettings < Holder
    field 'title' do
      "#{Burke.settings.name} #{Burke.settings.version}"
    end
    
    field 'files' do
      fl = FileList.new
      fl.include "lib/**/*.rb"
      fl.include(([readme_file] + extra_files).compact)
      fl.to_a.freeze
    end
    
    field 'extra_files' do
      [license_file].compact.freeze
    end
    
    field 'readme_file' do
      find_file('readme{.*,}').freeze
    end
    
    field 'license_file' do
      find_file('{licen{c,s}e,copying}{.*,}').freeze
    end
    
    field 'markup' do
      case File.extname(readme_file).downcase
      when '.rdoc'
        'rdoc'
      when '.md', '.markdown'
        'markdown'
      when '.textile'
        'textile'
      end.freeze
    end
    
    private
    def find_file pattern
      files = Dir.glob(pattern, File::FNM_CASEFOLD)
      files.find { |f| File.readable? f and File.file? f }
    end
  end
end

