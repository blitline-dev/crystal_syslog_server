require "./file_watcher"
require "json"

class JSONFileWatcher
	def initialize(file_watcher : FileWatcher, @debug : Bool)
  	@file_watcher = file_watcher
		@file_name = nil
		@file_watcher.watch
	end

	def watch_file(file_name : String, listener : Proc(Hash(String, JSON::Type), Nil))
		@file_name = file_name
		@file_watcher.add_file(file_name, ->{ reload(file_name, listener) })
		reload(file_name, listener)
	end

	private def reload(file_name : String, listener : Proc(Hash(String, JSON::Type), Nil))
		json = File.read file_name
		v = JSON.parse(json).as_h
		puts "Reloaded JSON File: #{v.inspect}" if @debug
  	listener.call(v)
	end

end
