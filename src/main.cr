require "./tcp.cr"

socat_proxy_port = ENV["CL_TCP_PORT"]? || "6768"
port = "1025"
stats_port = ENV["CL_STATS_TCP_PORT"]? || "6770"
cl_dir = ENV["CL_BASE_DIR"]? || "/var/log/commonlogs"
listen = ENV["CL_LISTEN"]? || "0.0.0.0"
debug = ENV["CL_DEBUG"]?.to_s == "true"

debug_type = 0
if ENV["CL_DEBUG_TYPE"]? && ENV["CL_DEBUG_TYPE"].to_i > 0
  debug_type = ENV["CL_DEBUG_TYPE"].to_i
end

# Make socat proxy
fork do
  io = IO::Memory.new
  cmd = "socat TCP-LISTEN:#{socat_proxy_port},fork TCP:#{port}"
  Process.run(cmd, shell: true, output: io)  
end

puts "Starting syslog server"
puts "TCP listening on #{listen}:#{socat_proxy_port}"
puts "Writing to #{cl_dir}"
puts "Logging TCP-IN" if debug_type == 1
server = Tcp.new(listen, port.to_i, cl_dir, debug, debug_type)
server.listen()
