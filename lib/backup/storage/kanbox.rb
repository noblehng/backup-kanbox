module Backup
  module Storage
    class Kanbox < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Kanbox API credentials
      attr_accessor :api_key, :api_secret

      ##
      # Remote upload path
      attr_accessor :path

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

      ##
      # Number of times to retry failed operations.
      #
      # Default: 5
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      #
      # Default: 5
      attr_accessor :retry_waitsec

      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'
        @cache_path ||= '.cache'
        @max_retries    ||= 5
        @retry_waitsec  ||= 5

        instance_eval(&block) if block_given?
      end

      private

      def connection
        unless @connection
          @connection = ::Kanbox::Client.new { }
          @connection.api_key = self.api_key
          @connection.api_secret = self.api_secret
        end

        @connection.access_token = create_session!
        @connection
      end

      def create_session!
        unless @session
          if File.exist?(cached_file)
            File.open(cached_file, 'rb') do |f|
              @session = OAuth2::AccessToken.from_hash(@connection.oauth_client, JSON.parse(f.read))
            end
          else
            puts "First use Kanbox you need authorize first!\n\n"
            puts @connection.authorize_url
            print "Type 'code' in callback url:"
            auth_code = $stdin.gets.chomp.split("\n").first
            @connection.token!(auth_code)
            @session = @connection.access_token
            save_session!
          end
        end
        refresh_session! if @session.expired?
        @session
      end

      def save_session!
        FileUtils.mkdir_p File.dirname(cached_file), :mode => 0700
        File.open(cached_file,"w", 0600) do |f|
          f.puts @session.to_hash.to_json
        end
      end

      def refresh_session!
        Logger.info "Access Token has expired, now refresh a new token..."
        @session = @session.refresh!
        Logger.info "Refresh successed. #{@session.token}"
        save_session!
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

          with_retries do
            result = connection.put(dest, src)
            unless result.success == true
              refresh_session! if result.error_code == '401'
              raise "HTTP status code: #{ result.error_code }"
            end
          end
        end

      rescue => err
        raise Error.wrap(err, 'Upload Failed!')
      end

      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError => err
          retries += 1
          raise if retries > max_retries

          Logger.info Error.wrap(err, "Retry ##{ retries } of #{ max_retries }.")
          sleep(retry_waitsec)
          retry
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
