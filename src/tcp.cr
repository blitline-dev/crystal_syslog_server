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
  end

	def reader(socket : TCPSocket, processor : Processor)
    while data = socket.gets
      formatted_data = processor.process(data)
			# Formatted Data: {"log_local_time" => "2016-08-14 00:30:58", "ingestion_time" => "2016-08-14 00:30:54 +0000",
			#  "body" => "ANTONY. Moon and stars!", "facility" => "local0", "severity" => "6"}
			Action.process(formatted_data)
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
