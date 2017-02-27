class StringMru
  struct MruData
    property updated_at : Time, value : String

    def initialize(@value : String, @updated_at : Time)
    end
  end

  def initialize(lifespan : Int64, filepath : String)
    @lifespan = lifespan
    @mru_hash = Hash(String, MruData).new
    @rough_time = Time.now
    @filepath = filepath
    start_cleaner
  end

  def add(value : String)
    @mru_hash[value] = MruData.new(value, @rough_time)
  end

  def get_recent : Array(MruData)
    @mru_hash.values
  end

  def write_recents
    file = File.open(@filepath, "w+")
    @mru_hash.each do |k,v|
      file.puts("#{k} #{v.updated_at.to_s("%s")}")
    end
    file.flush
    file.close
  end

  def start_cleaner
    spawn do
      loop do
        begin
          time_now = Time.now
          @rough_time = time_now
          @mru_hash.delete_if do |k, v|
            v.updated_at < time_now - @lifespan.seconds
          end
          write_recents
          sleep(60)
        rescue ex
          puts "Failed in string_mru"
          puts ex.message
        end
      end
    end
  end
end
