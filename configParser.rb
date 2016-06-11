require 'set'
require 'ostruct'

module Config 

	#global variables
	
	# two types of comments' identifiers
	COMMENTS = ['#', ';']
	
	#delimiters for overrides
	OVERRIDE_START = '<'
	OVERRIDE_END = '>'
	
	#regex expressions for groups, strings and boolean values
	REGEX_GROUP = /^\[[^\]\r\n]+\](?:\r?\n(?:[^\[\r\n].*)?)*/
	
	REGEX_STRING = /['"][^'"]*['"]/
	
	REGEX_BOOL_TRUE = /^(true|yes|1)$/i
	
	BOOLEAN_VALUES = %w(0 1 true false yes no)
	
	$current_group = nil
	$overridden = nil
	
	# the function being tested
	def load_config(file_path, overrides=[])
	
		#validate path.
		if file_path.nil? or not File.exist?(file_path)
			raise 'Provide valid file path '# << file_path
		end
		
		#empty hash for final result.
		result = {}
		
		#set globals to nil/ new set
		$current_group = nil
		$overridden = Set.new
		
		#after searching, I found that converting the symbols to strings was easier to do while comparing keys. I am injecting override.to_s here.
		#http://findnerd.com/list/view/Converting-string-to-symbol--symbol-to-string-in-rails/13647/
		overrides = overrides.inject([]) {|value, override|value << override.to_s}
		
		File.foreach(file_path) do |line|
			unless line
				next
			end
			process_line(line, overrides, result)
		end
		
		#returning result as an OpenStruct as it has a O(1) look up complexity. Since question mentioned quick query, I found this might be the a good structure instead of a Hash which still needs string/symbol comparison for keys.
		#http://stackoverflow.com/questions/1177594/when-should-i-use-struct-vs-openstruct
		OpenStruct.new(result)
	end
	
	#transform value into suitable format for CONFIG object
	def transform(value)
		if value =~ REGEX_STRING
			return value[1..value.length - 2]
		end
		
		if BOOLEAN_VALUES.include?(value)
			return !!(value =~ REGEX_BOOL_TRUE)
		end
		
		if is_numeric?(value)
			value = Float(value)
			return value % 1.0 == 0 ? value.to_i : value
		end
		
		if value.include?(',')
			values = []
			value.split(',').each do |val|
				values << transform(val)
			end
			
			return values
		end
		value
	end
	
	def is_numeric?(value)
		Float(value) != nil rescue false
	end
	
	#process the key, value, override tuple
	#store value for the last override in the file
	def process_key_val_override(key_val_override, overrides, result)
		key = key_val_override[:key]
		value = key_val_override[:value]
		override = key_val_override[:override_in_line]
		
		unless result.has_key?($current_group)
			result[$current_group] = ModifiedHash.new
		end
		
		if override.nil? and not $overridden.include?($current_group + key)
			result[$current_group][key] = transform(value)
		elsif overrides.include?(override)
			result[$current_group][key] = transform(value)
			$overridden.add($current_group + key)
		end
	end
	
	#processes the content in the group. creates a new hash for it.
	def process_group(group, result)
		if result.has_key?(group)
			raise 'Repeated group. Invalid config file. ' << group
		end
		
		result[group] = ModifiedHash.new
		#set global var to hold current group name. Used while processing key-val pair
		$current_group = group
	end
	
	#process each line
	def process_line(line, overrides, result)
		#trims the line and removes comments in the line 
		line = strip_comments(line)
		
		if line.empty? 
			return
		end
		
		#check if the line is a group name
		group = get_group_name(line)
		if group
			process_group(group, result)
			return
		end
		
		#check if the line is a key value pair
		key_val_override_tuple = get_key_val_override(line)
		if key_val_override_tuple
			process_key_val_override(key_val_override_tuple, overrides, result)
			return
		end
		
		#if line is not a group or key-value pair after comments are removed, it is an invalid line.
		raise 'Incorrectly formed config file at ' << line
	end
	
	#removes ' ' and comments
	def strip_comments(line)
		line.strip!
		
		if line.start_with?(COMMENTS[0]) or line.start_with?(COMMENTS[1])
			return ''
		end
		
		comment_exists = (0 ... line.length).find_all {|i| line[i, 1] == COMMENTS[0] or line[i, 1] == COMMENTS[1]}
		
		if comment_exists.empty?
			return line
		end
		
		if comment_exists
			line1 = String.new(line)
			#ignore delimiters within the text in the line itself.
			#replace quoted string with ' ' for the length and then remove comments.
			#return original line with the newly calculated index values.
			#asked question in forum and got this idea.
			line.scan(REGEX_STRING).each do |item|
				line1.sub!(item,' ' * item.length)
			end

			comment_start = line1.index(COMMENTS[0])
			
			unless comment_start
				comment_start = line1.index(COMMENTS[1])
					unless comment_start
						return line
					end
			end
			
			output = line[0..comment_start - 1]
			#strip again for whitespace before comment 
			output.strip!
			return output
		end
		#if comment doesn't exist, return the line
		line
	end
	
	#checks if line has a group name
	def get_group_name(line)
		group_matcher = line.match(REGEX_GROUP)
		unless group_matcher
		#not a group
			return nil
		end
		
		group = group_matcher[0]
		
		#trim []
		group = group[1..group.length - 2]
		
		if group =~ /\s/
		#group name cannot contain anything other than alphanumeric characters
			raise 'Invalid group name ' << group
		end
		group
	end
	
	#check if line is a key value pair with override
	def get_key_val_override(line)
		override_in_line = nil
		unless line.include?("=")
		#not a key=value type of line.
			return nil
		end
		
		if line.index("=") == 0
		#= is the first character. not valid.
			raise 'Invalid config file at line: ' << line
		end
		
		split_index = line.index("=")
		
		#get key and value based on position of =
		key = line[0..split_index - 1]
		value = line[split_index + 1..line.length]
		key.strip!
		value.strip!
		
		#determine if key has an override.
		if key.include?(OVERRIDE_START) and key.include?(OVERRIDE_END)
			override_start_index = key.index(OVERRIDE_START)
			override_end_index = key.index(OVERRIDE_END)
			override_in_line = key[override_start_index + 1..override_end_index - 1]
			key = key[0..override_start_index - 1]
			
			key.strip!
			override_in_line.strip!
			
			if key.empty? or override_in_line.empty?
			#either key is empty or the data within <> is empty
				raise 'Invalid config file at line: ' << line
			end
		end
		
		#return the tuple with key, value, override data
		{:key => key, :value => value, :override_in_line => override_in_line}
	end
	
	
			
	class ModifiedHash < Hash
#http://technicalpickles.com/posts/using-method_missing-and-respond_to-to-create-dynamic-methods/
		#this returns objects as a symbolized key and value pair.
		def []=(key, value)
		  super(key.to_sym, value)
		end
		
		#if method is missing, then return the value in the hash.
		#this allow object like access with chaining.
		
		def method_missing(method)
		  self[method]
		end

	end

end
	
		