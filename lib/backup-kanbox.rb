require "backup"

Backup::Storage.send(:autoload, :Kanbox, File.join(File.dirname(__FILE__),"backup/storage/kanbox"))