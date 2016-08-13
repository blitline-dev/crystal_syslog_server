class Frame
  def self.from_io(io)
    request_line = io.gets
    return unless request_line

	  puts request_line.inspect
  end
end
