require "backup"
require "json"
require "kanbox"
require "oauth2"

Backup::Storage.send(:autoload, :Kanbox, File.join(File.dirname(__FILE__),"backup/storage/kanbox"))