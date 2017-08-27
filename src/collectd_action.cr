require "secure_random"
require "json"
require "./file_manager"
require "./json_file_watcher"
require "./string_mru"

class CollectDAction
  PRIV_TOKEN = ENV["CL_PRIV_TOKEN"]? || ""
  PRIV_TOKEN_SIZE = PRIV_TOKEN.size + 1
  SUPPORTED_TAGS = { "aggregation-cpu-average" => ["cpu-idle"], "load" => ["load"], "memory" => ["memory-used", "memory-buffered", "memory-cached","memory-free"], "df-root" => ["percent_bytes-free","percent_bytes-reserved"] }

  def initialize(@file_root : String, @debug : Bool)
    @sec = !PRIV_TOKEN.blank?
    @host_mru = StringMru.new(3600_i64, "#{@file_root}/collectd")
    @channel = Channel::Buffered(CollectDData).new
    build_channel(@channel)
    puts "Secure = #{@sec}"
  end

  def process(data : CollectDData | Nil)
    return unless data

    if @sec
      priv_token = data.preamble.split("--")[1]

      unless priv_token == PRIV_TOKEN
        raise "Illegal call, bad PRIV_TOKEN #{data}"
      end
    end
    @channel.send data
  end

  private def build_channel(ch : Channel(CollectDData))
    spawn do
      loop do
        begin
          data_struct = ch.receive
          handlle_output(data_struct)
        rescue ex
          p "Error in action:loop! #{data_struct.inspect}"
          p ex.message
        end
      end
    end
  end

  private def handlle_output(data_struct : CollectDData)
    host = data_struct.host
    tag = data_struct.tag
    data = data_struct.data
    timestamp = data_struct.timestamp

    first_tag = tag[0]
    second_tag = tag[1]
    if first_tag && SUPPORTED_TAGS.has_key?(first_tag)
      if second_tag && SUPPORTED_TAGS[first_tag].includes?(second_tag)
        @host_mru.add("#{host}::#{tag.join('.')}::#{data}::#{timestamp}")
      end
    end
    
  end 
end