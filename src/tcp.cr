require "openssl" ifdef !without_openssl
require "socket"
require "./processor.cr"
require "./frame"
require "./action"
class Tcp

  def self.new(port)
    new("0.0.0.0", port)
  end

  def initialize(@host : String, @port : Int32)
		@action = Action.new("/tmp/")
		@connections = 0
  end

	def reader(socket : TCPSocket, processor : Processor)
		line_count = 0
		data = socket.gets
		max_lines = @connections > 35 ? 10000 : 1000
    while line_count < max_lines && data
			line_count += 1
	    formatted_data = processor.process(data)
			p formatted_data.inspect
			@action.process(formatted_data)
			data = socket.gets
    end
	end

	def spawn_listener(socket_channel : Channel)
		40.times do
      spawn do
        loop do
          socket = socket_channel.receive
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
			p socket.inspect
  		ch.send socket
		end 
  end

end
