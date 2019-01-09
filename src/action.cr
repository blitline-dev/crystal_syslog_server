require "json"
require "./file_manager"
require "./json_file_watcher"
require "./string_mru"

class Action
  EVENT_CONFIG_NAME    = "event_name"
  EVENT_CONFIG_FIND    = "find"
  EVENT_CONFIG_FINDEX  = "findex"
  EVENT_CONFIG_REPLACE = "replace"
  EVENT_BODY           = "body"
  TAG                  = "tag"
  PRIV_TOKEN           = ENV["CL_PRIV_TOKEN"]? || ""
  PRIV_TOKEN_SIZE      = PRIV_TOKEN.size + 1
  SIZE_LIMIT           = ENV.has_key?("CL_SIZE_LIMIT") ? ENV["CL_SIZE_LIMIT"].to_i64 : 70_000_000_000

  def initialize(@file_root : String, @debug : Bool)
    @sec = !PRIV_TOKEN.blank?
    @host_mru = StringMru.new(782400_i64, "#{@file_root}/hosts")
    @file_watcher = FileWatcher.new
    @events = Hash(String, JSON::Any).new
    setup_configs(@file_watcher)
    @file_manager = FileManager.new(@file_root, SIZE_LIMIT)
    @channel = Channel::Buffered(SyslogData).new
    build_channel(@channel)
    puts "Secure = #{@sec}"
  end

  def open_file_count
    @file_manager.open_file_count
  end

  def setup_configs(file_watcher : FileWatcher)
    # Events Config
    json_watcher = JSONFileWatcher.new(file_watcher, @debug)
    r = Proc(JSON::Any, Nil).new { |x| @events = x["events"].as(JSON::Any) }
    filepath = "#{@file_root}/events.json"
    data = "{ \"events\" : {} }"
    File.write(filepath, data) unless File.exists?(filepath)
    json_watcher.watch_file(filepath, r)
  end

  def process(data : SyslogData | ::Nil)
    puts "Action is processing #{data}" if @debug
    return unless data
    if @sec
      unless data.tag.starts_with?(PRIV_TOKEN)
        raise "Illegal call, bad PRIV_TOKEN #{data}"
      end
      data.tag = data.tag.byte_slice(PRIV_TOKEN_SIZE)
    end
    @channel.send data
  end

  private def build_channel(ch : Channel(SyslogData))
    spawn do
      loop do
        begin
          data_hash = ch.receive
          if (data_hash.facility[0..4] == "local" || @sec) && !@file_manager.paused
            @file_manager.write_to_file(data_hash, nil) do |file|
              handlle_output(data_hash, file)
            end
            check_events(data_hash)
          end
        rescue ex
          p "Error in action:loop! #{data_hash.inspect}"
          p ex.message
        end
      end
    end
  end

  private def handlle_output(data_hash : SyslogData, file : File)
    time = data_hash.ingestion_time
    suid = data_hash.suid
    host = data_hash.host
    tag = data_hash.tag
    body = data_hash.body

    @host_mru.add("#{host}:'#{tag}'")
    puts "Writing to file #{data_hash.to_s}" if @debug
    file.puts("#{time} #{suid} #{host} #{tag} #{body}")
  end

  private def check_events(data_hash)
    tag = data_hash.tag
    events_for_tag = @events[tag]?.as(Hash(String, JSON::Any) | Nil)
    return unless events_for_tag

    puts "Checking Events..." if @debug
    events_for_tag.keys.each do |event_key|
      # Compiler workaround
      b = events_for_tag[event_key].as(Hash(String, JSON::Any))
      name = b.fetch(EVENT_CONFIG_NAME, nil).to_s
      find = b.fetch(EVENT_CONFIG_FIND, nil).to_s
      findex = b.fetch(EVENT_CONFIG_FINDEX, nil).to_s
      replace = b.fetch(EVENT_CONFIG_REPLACE, nil).to_s
      # End compiler workaround
      handle_find(data_hash, find, name, false) unless find.empty?
      handle_find(data_hash, find, name, true) unless findex.empty?
    end
    puts "... Done Checking Events" if @debug
  end

  private def handle_find(data_hash : SyslogData, find : String, name : String, is_regex : Bool)
    if is_regex
      regex = Regex.new(find)

      md = data_hash.body.match(regex)
      if md
        write_event(data_hash, name)
      end
    else
      if data_hash.body.includes?(find)
        write_event(data_hash, name)
      end
    end
  end

  private def write_event(data_hash : SyslogData, event_name : String)
    @file_manager.write_to_file(data_hash, event_name) do |file|
      puts "Writing Event #{event_name}" if @debug
      handlle_output(data_hash, file)
    end
  end
end
