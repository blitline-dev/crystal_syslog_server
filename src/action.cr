require "secure_random"
require "json"
require "./file_manager"
require "./json_file_watcher"

class Action
	EVENT_CONFIG_NAME = "event_name"
	EVENT_CONFIG_FIND = "find"
	EVENT_CONFIG_FINDEX = "findex"
	EVENT_CONFIG_REPLACE = "replace"
	EVENT_BODY = "body"
	TAG = "tag"

	def initialize(@file_root : String, @debug : Bool)
		@file_watcher = FileWatcher.new
		@events = Hash(String, JSON::Type).new
		setup_configs(@file_watcher)
		@file_manager = FileManager.new(@file_root)
		@channel = Channel(Hash(String, String)).new
		build_channel(@channel)
	end

	def setup_configs(file_watcher : FileWatcher)
		# Events Config
    json_watcher = JSONFileWatcher.new(file_watcher, @debug)
    r = Proc(Hash(String, JSON::Type), Nil).new { |x| @events = x["events"] as Hash(String, JSON::Type) }
		filepath = "#{@file_root}/events.json"
		data = "{ \"events\" : {} }"
		File.write(filepath, data) unless File.exists?(filepath)
    json_watcher.watch_file(filepath, r )
	end

	def process(data : Hash(String, String) | ::Nil)
		puts "Action is processing #{data}" if @debug
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
		tag = data_hash[TAG]
		events_for_tag = @events[tag]? as Hash(String, JSON::Type) | Nil
		return unless events_for_tag

		puts "Checking Events..." if @debug
		events_for_tag.keys.each do |event_key|
			# Compiler workaround
			b = events_for_tag[event_key].as(Hash(String, JSON::Type))
			name = b.fetch(EVENT_CONFIG_NAME, nil).to_s
			find = b.fetch(EVENT_CONFIG_FIND, nil).to_s
			findex = b.fetch(EVENT_CONFIG_FINDEX, nil).to_s
			replace = b.fetch(EVENT_CONFIG_REPLACE, nil).to_s
			# End compiler workaround
			handle_find( data_hash, find, name, false) unless find.empty?
      handle_find( data_hash, find, name, true) unless findex
		end
		puts "... Done Checking Events" if @debug
	end

	private def handle_find(data_hash : Hash(String, String), find : String, name : String, is_regex : Bool)
		if is_regex
			regex = Regex.new(find)
			data_hash[EVENT_BODY].match(regex) do
				write_event(data_hash, name)
			end
		else
			if data_hash[EVENT_BODY].includes?(find)
    		write_event(data_hash, name)
			end
		end
	end

	private def write_event(data_hash : Hash(String, String), event_name : String)
    @file_manager.write_to_file(data_hash, event_name) do |file|
			puts "Writing Event #{event_name}" if @debug
      handlle_output(data_hash, file)
    end
	end

end
