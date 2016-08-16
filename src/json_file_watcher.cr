require "./file_watcher"
require "json"

class JSONFileWatcher
	def initialize(file_watcher : FileWatcher)
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
		p v.inspect
  	listener.call(v)
	end

end

#class MyClass
#	@data : Hash(String, JSON::Type) | Nil
#
#	def initialize
#		file_watcher = FileWatcher.new
#		json_watcher = JSONFileWatcher.new(file_watcher)
#		r = Proc(Hash(String, JSON::Type), Nil).new { |x| update_data(x) }
#		json_watcher.watch_file("events.json", r )
#	end
#
#	def update_data(updated_data : Hash(String, JSON::Type))
#		puts "Updated #{updated_data.inspect}"
#		@data = updated_data
#	end
#end

