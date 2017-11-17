struct CollectDData
  EMPTY = ""
  property preamble : String
  property host : String
  property tag : Array(String)
  property data : String
  property timestamp : String

  def initialize(@preamble=EMPTY, @host=EMPTY, @tag=Array(String).new, @data=EMPTY, @timestamp=EMPTY)
  end
end

class CollectDProcessor
  TAG_TOKENIZER = "."
  SPACE = " "

  def initialize
  end

  def process(data : String) : CollectDData | Nil
    begin
      if data
        return_struct = split_data(data)
        return nil if return_struct.tag.empty?
        return return_struct
      end
    rescue ex
      if ex.message.to_s.includes?("Illegal Token")
        puts "DATA=#{data}"
        puts ex.message
      else
        puts "In collectd_process:"
        puts "DATA=#{data}"
        puts ex.message
        puts ex.callstack
      end
    end
    return nil
  end

  def determine_format(data : String) : Hash(Symbol, Array(String))
    total_segments = data.split(SPACE)

    pre_amble = total_segments.shift
    first_segments = pre_amble.split(TAG_TOKENIZER, 8)
    first_segments.reject! {|s| s.nil? || s.empty?}
    if first_segments.nil?
      raise "First segment nil!!! data=#{data}"
    end

    if first_segments[0].includes?("collectd")
      return { :valid_data => first_segments, :data_and_timestamp => total_segments }
    end

    return { :valid_data => Array(String).new }
  end

  def build_tag(segments : Array(String)) : Array(String)
    return_array = Array(String).new
    base_tag = segments[0]
    subtag = segments[1]
    segments.shift
    segments.shift
    sub_subtag = ""
    return_array << base_tag
    return_array << subtag
    if segments.size > 0
      sub_subtag = segments[0]
      segments.shift
      return_array << sub_subtag
    end
    return return_array
  end

  def normalize(segments : Array(String), data_and_timestamp : Array(String)) : CollectDData
    output = CollectDData.new

    output.data = data_and_timestamp.shift
    output.timestamp = data_and_timestamp.shift

    # Build rest from segments
    output.preamble = segments.shift
    output.host = segments.shift
    

    output.tag = build_tag(segments)

    return output 
  end

  def split_data(data : String) : CollectDData
    type_and_data = determine_format(data)
    log_data = type_and_data[:valid_data]
    data_and_timestamp = type_and_data[:data_and_timestamp]
    return CollectDData.new if log_data.size == 0

    output = normalize(log_data, data_and_timestamp)
    return output
  end

end