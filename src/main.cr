puts "Starting RELP server"
puts "listening on 0.0.0.0:6768" 
puts "Writing to /var/log/commonlogs"
require "./tcp.cr"

server = Tcp.new(6768, "/var/log/commonlogs")
server.listen()
