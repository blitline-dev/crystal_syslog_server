      # Formatted Data: {"log_local_time" => "2016-08-14 00:30:58", "ingestion_time" => "2016-08-14 00:30:54 +0000",
      #  "body" => "ANTONY. Moon and stars!", "facility" => "local0", "severity" => "6"}
class Action

	def initialize
		@channel = Channel(Hash(String, String)).new
		@files = Hash(String,File).new
	end

	def process(data)
		@channel.send data
	end

	def build_channel(ch : Channel(Hash(String, String)))
		spawn do
       loop do
         data_hash = ch.receive
				 write_to_file(data_hash)
       end
     end
	end

	def write_to_file(data_hash : Hash(String, String))
		file_name = verify_file_name(data_hash["tag"])
		file = @files[file_name]

		if file.nil?
			file = create_open_file(file_name)
			@files[file_name] = file
		end

		file.puts(file_name)
	end
	
	def verify_file_name(name : String) : String
		# TODO: Validate string to make sure it looks like a filename
		return name
	end

	def create_open_file(filename : String)
		File.open("/tmp/#{filename}.log", "a")
	end

end

Action.new
