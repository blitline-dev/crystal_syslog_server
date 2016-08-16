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
  end

	def reader(socket : TCPSocket, processor : Processor)
    while data = socket.gets
      formatted_data = processor.process(data)
			p formatted_data.inspect
			@action.process(formatted_data)
    end
	end

	def spawn_listener(socket_channel : Channel)
		3.times do
      spawn do
        loop do
          socket = socket_channel.receive
					processor = Processor.new
					reader(socket, processor)
          socket.close
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
