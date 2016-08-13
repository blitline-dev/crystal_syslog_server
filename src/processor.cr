# ["<134>Aug", "13", "00:27:32", "nat", "shake@nat", "Tell", "him", "I'll", "send", "Duke", "Edmund", "to", "the", "Tower-\\n"]

class Processor
	LOOKUP_HASH = { "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6 , "Jul" => 7 , "Aug" => 8, "Sep" => 9,  "Oct" => 10, "Nov" => 11, "Dev" => 12}

  def process(data)
		puts split_data(data).inspect
  end

	def split_data(data : String)
		segments = data.split(" ")
		type_month = segments[0]
		hostname = segments[3]
    tag = segments[4]
		log_type = ""
    month = ""

		type_month.match(/<([0-9]*)>/) do |m|
			log_type = m[1] if m
		end

		type_month.match(/>(.*)/) do |m|
			month = m[1] if m
    end

		time = build_date(month, segments[1], segments[2])
		output = Hash(String, String).new

    output["log_local_time"] = time.to_s
		output["ingestion_time"] = Time.now.to_s
		output["log_type"] = log_type
		output["body"] = segments[5..-1].join(" ").strip
		return output
  end

	def build_date(month, day, time)
		year = Time.now.year
		hour_minute_seconds = time.split(":")
    built_time = Time.new(year, LOOKUP_HASH[month[0..2].camelcase], day.to_i, hour_minute_seconds[0].to_i, hour_minute_seconds[1].to_i, hour_minute_seconds[2].to_i)
		return built_time		
	end


end

