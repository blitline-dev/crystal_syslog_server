class FileWatcher

  struct FileData
		property updated_at : Time, listener : Proc(Nil), file_path : String

    def initialize(@file_path : String, @updated_at : Time, @listener : Proc(Nil))
    end
  end

  def initialize
    @files = Hash(String, FileData).new
    @channel = Channel(FileData).new
    build_channel(@channel)
  end

  def add_file( file_path : String, listener : Proc(Nil))
    file_data = FileData.new(file_path, Time.now, listener)
    @files[file_path] = file_data
  end

  def watch
    spawn do 
      loop do
        @files.each do | name, file_data |
          if has_changed(name, file_data)
            @channel.send(file_data)
          end
        end
        sleep 1
      end
    end
  end

  private def build_channel(ch : Channel(FileData))
    spawn do
       loop do
          file_data = ch.receive
          if file_data
            file_data.listener.call
          end
       end
     end
  end

  private def has_changed(name : String, file_data : FileData) : Bool
    if File.stat(name).mtime > file_data.updated_at
      file_data.updated_at = File.stat(name).mtime
      @files[name] = file_data
      return true
    end

    return false
  end

end

