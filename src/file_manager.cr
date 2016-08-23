require "file_utils"

class FileManager

  class OpenFile
		property file, buffer_size, last_written
    def initialize(file : File, buffer_size : Int32)
			@file = file
			@buffer_size = buffer_size
			@last_written = Time.now.epoch as Int64
    end
  end

	def initialize(@root_url : String)
  	@files = Hash(String,OpenFile).new
	end

  def write_to_file(data_hash : Hash(String, String), event_name : String | Nil)
		open_file = get_open_file(data_hash, event_name)
    file = open_file.file

		yield file

    unless event_name.nil?
			time_now = Time.now.epoch
			if open_file.last_written < time_now - 120
					# Forcing file flush for events that haven't
					# written in over 2 minutes
					open_file.file.flush
			end
 			open_file.last_written = time_now
		end
  end

	def get_open_file(data_hash : Hash(String, String), event_name : String | Nil)
		tag = verify_file_name(data_hash["tag"])
		sub_path = tag
		if event_name
			event_name = verify_file_name(event_name)
			sub_path = "#{tag}/events/#{event_name}"
		end
		time = data_hash["ingestion_time"]
    file_path = build_file_path(sub_path, time)

    open_file = @files[file_path]?
    if open_file.nil?
      open_file = open_file(file_path)
      @files[file_path] = open_file
    end

    if open_file.nil?
      open_file = open_file(file_path)
      @files[file_path] = open_file
    end
		return open_file
	end

  def verify_file_name(name : String) : String
    # TODO: Validate string to make sure it looks like a filename
		name = name.sub(/[\/\\\0\`\*\|\;\"\'\:]/,"")
    return name
  end

  def open_file(filepath : String) : OpenFile
		dir_name = File.dirname(filepath)
		unless File.directory?(dir_name)
  		mkdir_p(dir_name)
		end
    f = File.open(filepath, "a")
		cleanup_files
    new_open_file = OpenFile.new(f, 0)
  end

  def build_file_path(tag : String, time : String) : String
    time_obj = Time.epoch(time.to_i)
    file_name = time_obj.to_s("%Y-%m-%d-%H.log")
    file_path = "#{@root_url}/#{tag}/#{file_name}"
    return file_path
  end

	def cleanup_files
		time = Time.now.to_s("%Y-%m-%d-%H.log")

		# Close and delete files if they are old
		@files.delete_if do |k,v|
			result = false
			filename = File.basename(k)
			if filename < time
				v.file.close
				result = true
			end
			result
		end
	end

	def mkdir_p(path : String)
		process_run("mkdir -p #{path}")
  end

	def process_run(cmd : String)
		io = MemoryIO.new
		Process.run(cmd, shell: true, output: io)
		output = io.to_s
	end

end
