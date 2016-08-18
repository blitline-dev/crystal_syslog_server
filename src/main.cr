puts "Starting RELP server"
puts "listening on 0.0.0.0:6768"

require "./tcp.cr"

server = Tcp.new(6768)
server.listen()
