require "file_utils"

class Downloader
  def self.download_certs
    begin
      #   https://s3.amazonaws.com/commonlogs.install/certs/dark-sode/server.crt
      raise "Must have CL_CERT_BASE_PATH defined" unless ENV["CL_CERT_BASE_PATH"]?

      key_path = ENV["CL_CERT_BASE_PATH"] + "server.key"
      cert_path = ENV["CL_CERT_BASE_PATH"] + "server.crt"

      exc = "wget #{key_path} -O /etc/ssl/certs/server.key"
      process_run(exc)
      exc = "wget #{cert_path} -O /etc/ssl/certs/server.crt"
      process_run(exc)
      raise "no server.key" unless File.exists?("/etc/ssl/certs/server.key")
      raise "no server.crt" unless File.exists?("/etc/ssl/certs/server.crt")
    rescue ex
      puts "Failed to download certs..."
      puts ex.message
      exit 0
    end
  end

  def self.process_run(cmd : String)
    io = IO::Memory.new
    Process.run(cmd, shell: true, output: io)
    output = io.to_s
  end

end