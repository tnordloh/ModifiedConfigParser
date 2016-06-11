require 'test/unit'
require_relative 'configParser'
include Config
#this is a file I used to test after each change.
class TestConfig 
	
    CONFIG = load_config('test_configs/good-config.conf', ['ubuntu', :production])

	
	puts CONFIG['common']
	puts
	puts CONFIG.common.paid_users_size_limit
	puts
	puts CONFIG.ftp.name
	puts
	puts CONFIG.ftp.path
	puts
	puts CONFIG.ftp.lastname
    

end