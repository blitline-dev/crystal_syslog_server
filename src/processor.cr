require "./type_table"
# Syslog:
# <134>Jan 16 21:07:33 cedis-1 cedis[1072]: jj6GZ LCREATE list:0W19rxER7il4KtrCsDCOcQg
# Micro:
# 101 <134>1 2017-01-16T21:08:43.287929Z cedis-1 cedis 1072 cedis jj6GZ GETINT int:7N5_Ot_unayZ07ASfqQvYgg
# Rsyslog_full:
# 73 <134>1 2017-01-16T21:09:32Z cedis-1 cedis 1072 cedis Index out of bounds
# Rsyslog_plus:
# <134>Jan 16 21:13:32 cedis-1 cedis jj6GZ DECR int:1hbE8qxgL5ngpcWc3EdQ6nw 1

class Processor
  LOOKUP_HASH = { "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6 , "Jul" => 7 , "Aug" => 8, "Sep" => 9,  "Oct" => 10, "Nov" => 11, "Dec" => 12}
  TOKEN = ENV["CL_TOKEN"]?
  TAG_TOKENIZER = ">"
  VERSIONS = [:syslog, :rsyslog_micro, :rsyslog_full, :rsyslog_plus]

  def initialize
    @atomic_index = 0
  end

  def process(data : String) : Hash(String, String) | Nil
    begin
      if data
        hash = split_data(data)
        if hash.empty?
          return Hash(String, String).new
        end

        return hash
      end
    rescue ex
      if ex.message.to_s.includes?("Illegal Token")
        puts "DATA=#{data}"
        puts ex.message
      else
        puts ex.message
        puts ex.callstack
      end
    end
    return nil
  end

  def determine_format(data : String) : Hash(Symbol, Array(String))
    pre_amble = data
    first_segments = pre_amble.split(" ", 8)
    first_segments.reject! {|s| s.nil? || s.empty?}
    if first_segments.nil?
      raise "First segment nil!!!"
    end

    if first_segments[0].includes?("<")
      # Starts with '<134>Jan 16 21:07:33'
      # primitive or rsyslog
      if first_segments[4].includes?("[")
        return { :primitive => first_segments }
      else
        return { :rsyslog => first_segments }
      end
    else
      # Starts with '123 <134>Jan 16 21:07:33'
      # micro or rsyslog_full
      first_segments.shift # Delete first integer
      if first_segments[2].includes?(".")
        return { :rsyslog_micro => first_segments }
      else
        return { :rsyslog_full => first_segments }
      end
    end
  end

  def get_facility_from_segment(segment : String)
    facility = "unknown"
    md = segment.match(/<([0-9]*)>(1?)/) 
    if md
      facility = TypeTable.define(md[1].to_i)
    else
      raise "Failed facility #{segment}"
    end
    return facility
  end

  def get_timestamp_from_segment(segments : Array(String))
    segment = segments[0]
    md = segment.match(/>([a-zA-Z].*)/) 
    segments.shift
    if md
      month = md[1] 
      time = build_date(month, segments[1], segments[2])
      segments.shift(2)
    else
      # New Timestamp format
      begin
        time = Time.parse(segment, "%Y-%m-%dT%H:%M:%S", Time::Kind::Utc)
      rescue bs
        puts bs.inspect_with_backtrace
        time = Time.now
      end
      segments.shift
    end
    return time
  end


  def normalize(segments : Array(String)) : Hash(String, String)
    output = Hash(String, String).new
    segment = segments[0]
    # Determine Fac/Sev
    fac_sev = get_facility_from_segment(segment)
    output["facility"] = fac_sev[1].to_s
    output["severity"] = fac_sev[0].to_s
    # Determine Time
    time = get_timestamp_from_segment(segments)
    output["log_local_time"] = time.to_s("%s")

    output["host"] = segments[0]
    segments.shift

    output["tag"] = validate_tag(segments[0])
    segments.shift

    output["body"] = segments.join(" ").strip
    output["suid"] = atomic_counter.to_s
    output["ingestion_time"] = Time.now.to_s("%s")
    return output
  end



  def normalize_data(log_type : Symbol, segments : Array(String) ) : Hash(String, String)
    output = Hash(String, String).new
    case log_type
    when :primitive 
      output = normalize(segments)
    when :rsyslog
      output = normalize(segments)
    when :rsyslog_micro
      output = normalize(segments)
    when :rsyslog_full
      output = normalize(segments)
    end

    return output
  end

  def split_data(data : String) : Hash(String, String)
    type_and_data = determine_format(data)
    log_type = type_and_data.keys[0]
    log_data = type_and_data[log_type]

    output = normalize_data(log_type, log_data)
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
