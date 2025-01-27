require "socket"
require "./processor.cr"
require "./collectd_processor.cr"
require "./collectd_action.cr"
require "./action"

class Tcp
  TOTAL_FIBERS = 200

  def initialize(@host : String, @port : Int32, @base_dir : String, @debug : Bool, @debug_type : Int32)
    @action = Action.new(@base_dir, @debug)
    @connections = 0
    @version = ENV["CL_VERSION"]? || "0.0.0.0"
    @processor = Processor.new
    @collectd_processor = CollectDProcessor.new
    @collectd_action = CollectDAction.new(@base_dir, @debug)
    Signal::USR1.trap do
      @debug = !@debug
      @debug_type == 0 ? @debug_type == 1 : @debug_type == 0
      puts "Debug now: #$debug"
    end
  end

  def get_socket_data(socket : TCPSocket)
    begin
      socket.each_line do |line|
        puts line.to_s if @debug_type == 1
        yield(line)
      end
    rescue ex
      if @debug
        puts "From Socket Address:" + socket.remote_address.to_s if socket.remote_address
        puts ex.inspect_with_backtrace
      end
    end
  end

  def reader(socket : TCPSocket, processor : Processor)
    get_socket_data(socket) do |lines|
      if lines
        lines.each_line do |data|
          if data.to_s[0..4] == "stats"
            p "Stats"
            stats_response(socket)
            return
          end

          puts "Recieved: #{data}" if @debug

          if data && data.size > 5
            begin
              if data.to_s[0..7] == "collectd"
                formatted_data = @collectd_processor.process(data)
                @collectd_action.process(formatted_data)
              else
                return unless data.valid_encoding?
                formatted_data = processor.process(data)
                @action.process(formatted_data)
                data = nil
              end
            rescue ex
              puts ex.message
              puts "Data:#{data}"
              puts "Remote address #{socket.remote_address.to_s}" if socket.remote_address
            end
          end
        end
      end
    end
  end

  def stats_response(socket : TCPSocket)
    data = {
      "version"         => @version,
      "debug"           => @debug,
      "connections"     => @connections,
      "port"            => @port,
      "available"       => TOTAL_FIBERS,
      "open_file_count" => @action.open_file_count,
    }
    p "Stats Response #{data}"
    socket.puts(data.to_json)
  end

  def spawn_listener(socket_channel : Channel)
    TOTAL_FIBERS.times do
      spawn do
        loop do
          begin
            socket = socket_channel.receive
            socket.read_timeout = 15.seconds
            @connections += 1
            reader(socket, @processor)
            socket.close
            @connections -= 1
          rescue ex
            if socket
              socket.close
            end
            @connections -= 1
            puts "Error in spawn_listener"
            puts ex.message
          end
        end
      end
    end
  end

  def listen
    ch = build_channel
    server = TCPServer.new(@host, @port)

    spawn_listener(ch)
    begin
      loop do
        socket = server.accept
        ch.send socket
      end
    rescue ex
      puts "Error in tcp:loop!"
      puts ex.message
    end
  end

  def build_channel
    Channel(TCPSocket).new
  end
end
