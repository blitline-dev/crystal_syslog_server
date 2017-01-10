require "openssl" ifdef !without_openssl
require "socket"
require "./processor.cr"
require "./action"
class Tcp

  TOTAL_FIBERS = 200

  def initialize(@host : String, @port : Int32, @base_dir : String, @debug : Bool, @debug_type : Int32)
		@action = Action.new(@base_dir, @debug)
		@connections = 0
    @version = ENV["CL_VERSION"]? || "0.0.0.0"
    @processor = Processor.new
  end

  def get_socket_data(socket : TCPSocket)
    data = nil
    begin
      data = socket.gets
      puts data.to_s if @debug_type == 1
    rescue ex
      if @debug
        puts ex.inspect_with_backtrace 
        puts "From Socket Address:" + socket.remote_address.to_s if socket.remote_address
      end
    end
    return data
  end

	def reader(socket : TCPSocket, processor : Processor)
  	data = get_socket_data(socket)

    if data == "stats\n"
      p "Stats"
      stats_response(socket)
      return
    end

    puts "Recieved: #{data}" if @debug
    while data
			if data && data.size > 5
				begin
		  	  formatted_data = processor.process(data)
					@action.process(formatted_data)
				rescue ex
					p ex.message
					p "Data:#{data}"
   	    end
        data = get_socket_data(socket)
		  end
    end
	end

  def stats_response(socket : TCPSocket)
    data = {
      "version" : @version,
      "debug" : @debug,
      "connections" : @connections,
      "port" :  @port,
      "available" : TOTAL_FIBERS,
      "open_file_count" : @action.open_file_count
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
            socket.read_timeout = 3
  					@connections += 1
  					reader(socket, @processor)
            socket.close
  					@connections -= 1
          rescue ex
            p "Error in spawn_listener"
            p ex.message
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
      p "Error in tcp:loop!"
      p ex.message
    end
  end

  def build_channel
    Channel(TCPSocket).new
  end


end
