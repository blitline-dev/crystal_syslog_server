require "openssl" ifdef !without_openssl
require "socket"
require "./processor.cr"
require "./frame"
class Tcp

  @wants_close = false

  def self.new(port)
    new("0.0.0.0", port)
  end

  def initialize(@host : String, @port : Int32)
  end

  def listen
		ch = Channel(TCPSocket).new
		server = TCPServer.new(@host, @port)

		3.times do
  		spawn do
    		loop do
      		socket = ch.receive
      		while data = socket.gets
						puts data
					end
      		socket.close
    		end
  		end
		end
		
		loop do
  		socket = server.accept
  		ch.send socket
		end
 
  end

end
