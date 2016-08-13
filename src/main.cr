puts "Starting RELP server"
puts "listening on 127.0.0.1:6768"

require "./tcp.cr"

server = Tcp.new(6768)
server.listen()
