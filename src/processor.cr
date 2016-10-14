require "./type_table"
# ["<134>Aug", "13", "00:27:32", "nat", "shake@nat", "Tell", "him", "I'll", "send", "Duke", "Edmund", "to", "the", "Tower-\\n"]
# {"log_local_time" => "2016-08-14 00:30:58", "ingestion_time" => "2016-08-14 00:30:54 +0000",
#  "body" => "ANTONY. Moon and stars!", "facility" => "local0", "severity" => "6"}

class Processor
  LOOKUP_HASH = { "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6 , "Jul" => 7 , "Aug" => 8, "Sep" => 9,  "Oct" => 10, "Nov" => 11, "Dev" => 12}
  TOKEN = ENV["CL_TOKEN"]?
  TAG_TOKENIZER = ">"

  def initialize
    @atomic_index = 0
  end

  def process(data : String) : Hash(String, String) | ::Nil
    begin
      if data
        hash = split_data(data)
        return hash
      end
    rescue ex
      if ex.message.to_s.includes?("Illegal Token")
        puts ex.message
      else
        puts ex.message
        puts ex.callstack
      end
    end
    return nil
  end

  def split_data(data : String) : Hash(String, String) | ::Nil
    segments = data.split(" ", 8)
    segments.reject! {|s| s.nil? || s.empty?}
    if segments.nil?
      return nil
    end
    type_month = segments[0]
    if type_month[0] != '<'
      # Sometimes syslog messages have their length at the beginning of the message
      segments.delete_at(0)
      type_month = segments[0]
    end

    log_type = ""
    month = ""
    hostname = ""
    tag = ""
    proc_id = ""
    msg_id = ""
    structured_data = ""

    body_start = 5

    version_one = false
    type_month.match(/<([0-9]*)>(1?)/) do |m|
      log_type = m[1] if m
      version_one = true if m[2] == "1"
    end

    if version_one
      iso_date_string = segments[1]
      begin
        time = Time.parse(iso_date_string, "%Y-%m-%dT%H:%M:%S", Time::Kind::Utc)
      rescue bs
        puts bs.inspect_with_backtrace
        time = Time.now
      end
      hostname = segments[2]
      tag = segments[3]

      proc_id = segments[4]
      msg_id = segments[5]
      structured_data = segments[6]

      body_start = 7
    else
      type_month.match(/>(.*)/) do |m|
        month = m[1] if m
      end
      hostname = segments[3]
      tag = segments[4]
      body_start = 5
      time = build_date(month, segments[1], segments[2])
    end

    output = Hash(String, String).new
    output["log_local_time"] = time.to_s("%s")
    output["host"] = hostname
    output["tag"] = validate_tag(tag)
    output["proc_id"] = proc_id
    output["msg_id"] = msg_id
    output["structured_data"] = structured_data
    output["suid"] = atomic_counter.to_s
    output["ingestion_time"] = Time.now.to_s("%s")
    output["body"] = segments[body_start..-1].join(" ").strip
    fac_sev = TypeTable.define(log_type.to_i)
    output["facility"] = fac_sev[1].to_s
    output["severity"] = fac_sev[0].to_s
    return output
  end

  def atomic_counter
    @atomic_index += 1
    @atomic_index = 0 if @atomic_index > 50_000_000
    return @atomic_index
  end

  def validate_tag(tag)
    if TOKEN
      tokenizer = tag.split(TAG_TOKENIZER)
      if tokenizer[0] != TOKEN
        raise "Illegal Token #{tag}"
      end
      return tokenizer[1]
    end
    return tag
  end


  def build_date(month : String, day : String , time : String)
    built_time = ""
    year = Time.now.year
    hour_minute_seconds = time.split(":")
    built_time = Time.new(year, LOOKUP_HASH[month[0..2].camelcase], day.to_i, hour_minute_seconds[0].to_i, hour_minute_seconds[1].to_i, hour_minute_seconds[2].to_i)
    return built_time
  end
end
