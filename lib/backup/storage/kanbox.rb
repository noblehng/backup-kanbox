module Backup
  module Storage
    class Kanbox < Base
      include Storage::Cycler
      attr_accessor :api_key, :api_secret, :path
      ##  
      # Path to store cached authorized session.
      #   
      # Relative paths will be expanded using Config.root_path,
      # which by default is ~/Backup unless --root-path was used
      # on the command line or set in config.rb.
      #   
      # By default, +cache_path+ is '.cache', which would be
      # '~/Backup/.cache/' if using the default root_path.
      attr_accessor :cache_path

      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'
        @cache_path ||= '.cache'

        instance_eval(&block) if block_given?
      end

      private

      def connection
        unless @connection
          @connection = ::Kanbox::Client.new { }
          @connection.api_key = self.api_key
          @connection.api_secret = self.api_secret
        end
        
        if session
          @connection.access_token = session
        else
          puts "First use Kanbox you need authorize first!\n\n"
          puts @connection.authorize_url
          print "Type 'code' in callback url:"
          auth_code = $stdin.gets.chomp.split("\n").first
          @connection.token!(auth_code)
          save_session(@connection.access_token)
          puts "Authorize successed!"
        end
        @connection
      end
      
      def save_session(s)
        @access_token = s
        File.open(cached_file,"w") do |f|
          f.puts @access_token.to_hash.to_json
        end
      end
      
      def session
        if File.exist?(cached_file)
          stored_data = File.open(cached_file).read
          @session = OAuth2::AccessToken.from_hash(@connection.oauth_client, JSON.parse(stored_data))
          if @session.expired?
            Logger.info "Access Token has expired, now refresh a new token..."
            @session = @session.refresh!
            Logger.info "Refresh successed. #{@session.token}"
            save_session(@session)
          end
        end
        @session
      end

      def cached_file
        @cache_path = cache_path.start_with?('/') ?
                      cache_path : File.join(Config.root_path, cache_path)
        File.join(cache_path, "kanbox-" + self.api_key + "-" + self.api_secret)
      end
      
      def transfer!
        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."
          connection.put(dest, src)
        end
      end

      def remove!(package)
        remote_path = remote_path_for(package)
        Logger.info "Removeing '#{remote_path}' from Kanbox..."
        connection.delete(remote_path)
      end
    end
  end
end
