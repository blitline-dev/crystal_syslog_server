require "./frame"

class Processor
  def initialize()
    @wants_close = false
  end

  def close
    @wants_close = true
  end

  def process(input, output, error = STDERR)
    must_close = true

    begin
      until @wants_close
        dat = Frame.from_io(input)
        # EOF
        output.flush
      end
    rescue ex : Errno
      # IO-related error, nothing to do
    ensure
      input.close if must_close
    end
  end
end
