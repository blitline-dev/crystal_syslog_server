require "openssl" ifdef !without_openssl
require "socket"
require "./processor.cr"
require "./frame"
class Tcp

  def self.new(port)
    new("0.0.0.0", port)
  end

  def initialize(@host : String, @port : Int32)
  end

	def reader(socket : TCPSocket, processor : Processor)
    while data = socket.gets
      processor.process(data)
    end
	end

	def spawn_listener(socket_channel : Channel, processor : Processor)
		3.times do
      spawn do
        loop do
          socket = socket_channel.receive
					reader(socket, processor)
          socket.close
        end
      end
    end
  end

  def listen
		ch = Channel(TCPSocket).new
		server = TCPServer.new(@host, @port)
		processor = Processor.new
		
		spawn_listener(ch, processor)
		loop do
  		socket = server.accept
  		ch.send socket
		end 
  end

end
