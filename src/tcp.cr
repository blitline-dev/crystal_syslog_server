require "socket"
require "./processor.cr"
require "./collectd_processor.cr"
require "./collectd_action.cr"
require "./action"

class Tcp
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
    data = ""
    begin
      if txt = socket.gets(2048, true)
        data += txt.to_s
      end
      puts data.to_s if @debug_type == 1
    rescue ex
      if @debug
        puts "From Socket Address:" + socket.remote_address.to_s if socket.remote_address
        puts ex.inspect_with_backtrace
      end
    end
    return data
  end

  def reader(socket : TCPSocket, processor : Processor)
    data = get_socket_data(socket)
    return if data.empty?

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
          formatted_data = processor.process(data)
          @action.process(formatted_data)
        end
      rescue ex
        p ex.message
        p "Data:#{data}"
        p "Remote address #{socket.remote_address.to_s}" if socket.remote_address
      end
    end
  end

  def stats_response(socket : TCPSocket)
    data = {
      "version"         => @version,
      "debug"           => @debug,
      "connections"     => @connections,
      "port"            => @port,
      "open_file_count" => @action.open_file_count,
    }
    p "Stats Response #{data}"
    socket.puts(data.to_json)
  end

  def handle_connection(socket : TCPSocket)
    # In new Fiber
    socket.read_timeout = 15
    #    socket.tcp_nodelay - true
    @connections += 1
    reader(socket, @processor)
    socket.close
    @connections -= 1
  end

  def listen
    server = TCPServer.new(@host, @port)

    begin
      loop do
        p "loop start"
        if socket = server.accept?
          # handle the client in a fiber
          spawn handle_connection(socket)
        else
          # another fiber closed the server
          break
        end
      end
    rescue ex
      p "Error in tcp:loop!"
      p ex.message
    end
  end
end
