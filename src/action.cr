require "secure_random"
require "json"
require "./file_manager"
require "./json_file_watcher"

      # Formatted Data: {"log_local_time" => "2016-08-14 00:30:58", "ingestion_time" => "2016-08-14 00:30:54 +0000",
      #  "body" => "ANTONY. Moon and stars!", "facility" => "local0", "severity" => "6"}
			# 1471144342 94925 ip-10-168-66-18 blitag Writing /tmp/to_ttf.pe...
class Action

	CONFIG_FILE = "events.json"

	def initialize(@file_root : String)
		@file_watcher = FileWatcher.new
		@events = Hash(String, JSON::Type).new
		setup_configs(@file_watcher)
		@file_manager = FileManager.new(@file_root)
		@channel = Channel(Hash(String, String)).new
		build_channel(@channel)
	end

	def setup_configs(file_watcher : FileWatcher)
		# Events Config
    json_watcher = JSONFileWatcher.new(file_watcher)
    r = Proc(Hash(String, JSON::Type), Nil).new { |x| @events = x["events"] as Hash(String, JSON::Type) }
    json_watcher.watch_file("events.json", r )
	end

	def process(data : Hash(String, String) | ::Nil)
		return unless data
		@channel.send data
	end

	private def build_channel(ch : Channel(Hash(String, String)))
		spawn do
       loop do
         data_hash = ch.receive
				 if data_hash["facility"][0..4] == "local"
					 	@file_manager.write_to_file(data_hash, nil) do |file|
							handlle_output(data_hash, file)
						end
			     check_events(data_hash)
				 end
       end
     end
	end

	private def handlle_output(data_hash : Hash(String, String), file : File)
		time = data_hash["ingestion_time"]
    suid = SecureRandom.urlsafe_base64(8)
    host = data_hash["host"]
    tag = data_hash["tag"]
    body = data_hash["body"]
    file.puts("#{time} #{suid} #{host} #{tag} #{body}")
	end

	private def check_events(data_hash)
		tag = data_hash["tag"]
		events_for_tag = @events[tag]? as Array(JSON::Type) | Nil
		return unless events_for_tag

		events_for_tag.each do |event|
			# Compiler workaround
			b = event.as(Hash(String, JSON::Type))
			name = b.fetch("name", Nil).to_s
			find = b.fetch("find", Nil).to_s
			findex = b.fetch("findex", Nil).to_s
			replace = b.fetch("replace", Nil).to_s
			# End compiler workaround
			handle_find( data_hash, find, name, false) unless find.empty?
      handle_find( data_hash, find, name, true) unless findex.empty?
		end
	end

	private def handle_find(data_hash : Hash(String, String), find : String, name : String, is_regex : Bool)
		if is_regex
			regex = Regex.new(find) 
			data_hash["body"].match(regex) do
				write_event(data_hash, name)
			end
		else	
			if data_hash["body"].includes?(find)
    		write_event(data_hash, name)
			end
		end	
	end

	private def write_event(data_hash : Hash(String, String), event_name : String)
    @file_manager.write_to_file(data_hash, event_name) do |file|
      handlle_output(data_hash, file)
    end
	end

end
