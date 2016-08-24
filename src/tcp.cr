require "openssl" ifdef !without_openssl
require "socket"
require "./processor.cr"
require "./action"
class Tcp

  def initialize(@host : String, @port : Int32, @base_dir : String, @debug : Bool)
		@action = Action.new(@base_dir, @debug)
		@connections = 0
  end

  def get_socket_data(socket : TCPSocket)
    daata = nil
    begin
      data = socket.gets
    rescue ex
      # Move to @debug
      puts ex.inspect_with_backtrace 
      puts "From Socket Address:" + socket.remote_address.to_s if socket.remote_address
    end
  end

	def reader(socket : TCPSocket, processor : Processor)
		line_count = 0
    socket.read_timeout = 20
  	data = get_socket_data(socket)
    puts "Recieved: #{data}" if @debug
		max_lines = @connections > 35 ? 10000 : 1000
    while line_count < max_lines && data
			if data && data.size > 5
				line_count += 1
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

	def spawn_listener(socket_channel : Channel)
		40.times do
      spawn do
        loop do
          socket = socket_channel.receive
          socket.read_timeout = 20
					@connections += 1
					processor = Processor.new
					reader(socket, processor)
          socket.close
					@connections -= 1
        end
      end
    end
  end

  def listen
		ch = Channel(TCPSocket).new
		server = TCPServer.new(@host, @port)

		spawn_listener(ch)
		loop do
  		socket = server.accept
  		ch.send socket
		end
  end

end
