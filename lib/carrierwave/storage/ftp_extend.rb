require 'carrierwave'
require 'carrierwave/storage/ftp_extend/ex_ftp'

module CarrierWave
  module Storage
    class FTPExtend < Abstract
      def store!(file)
        f = CarrierWave::Storage::FTPExtend::File.new(uploader, self, uploader.store_path)
        f.store(file)
        f
      end

      def retrieve!(identifier)
        CarrierWave::Storage::FTPExtend::File.new(uploader, self, uploader.store_path(identifier))
      end

      class File
        attr_reader :path

        def initialize(uploader, base, path)
          @uploader, @base, @path = uploader, base, path
        end

        def store(file)
          connection do |ftp|
            ftp.mkdir_p(::File.dirname "#{@uploader.ftp_extend_folder}/#{path}")
            ftp.chdir(::File.dirname "#{@uploader.ftp_extend_folder}/#{path}")
            ftp.put(file.path, filename)
          end
        end

        def url
          "#{@uploader.ftp_extend_url}/#{path}"
        end

        def filename(options = {})
          url.gsub(/.*\/(.*?$)/, '\1')
        end

        def to_file
          temp_file = Tempfile.new(filename)
          temp_file.binmode
          temp_file.write file.body
          temp_file
        end

        def size
          size = nil

          connection do |ftp|
            ftp.chdir(::File.dirname "#{@uploader.ftp_extend_folder}/#{path}")
            size = ftp.size(filename)
          end

          size
        end

        def exists?
          size ? true : false
        end

        def read
          file.body
        end

        def content_type
          @content_type || file.content_type
        end

        def content_type=(new_content_type)
          @content_type = new_content_type
        end

        def delete
          connection do |ftp|
            ftp.chdir(::File.dirname "#{@uploader.ftp_extend_folder}/#{path}")
            ftp.delete(filename)
          end
        rescue
        end

        private

        def use_ssl?
          @uploader.ftp_extend_url.start_with?('https')
        end

        def file
          require 'net/http'
          url = URI.parse(self.url)
          req = Net::HTTP::Get.new(url.path)
          Net::HTTP.start(url.host, url.port, :use_ssl => use_ssl?) do |http|
            http.request(req)
          end
        rescue
        end

        def connection
          ftp = ExFTP.new
          ftp.connect(@uploader.ftp_extend_host, @uploader.ftp_extend_port)

          begin
            ftp.passive = @uploader.ftp_extend_passive
            ftp.login(@uploader.ftp_extend_user, @uploader.ftp_extend_passwd)

            yield ftp
          ensure
            ftp.quit
          end
        end
      end
    end
  end
end

CarrierWave::Storage.autoload :FTPExtend, 'carrierwave/storage/ftp_extend'

class CarrierWave::Uploader::Base
  add_config :ftp_extend_host
  add_config :ftp_extend_port
  add_config :ftp_extend_user
  add_config :ftp_extend_passwd
  add_config :ftp_extend_folder
  add_config :ftp_extend_url
  add_config :ftp_extend_passive

  configure do |config|
    config.storage_engines[:ftp_extend] = "CarrierWave::Storage::FTPExtend"
    config.ftp_extend_host = "localhost"
    config.ftp_extend_port = 21
    config.ftp_extend_user = "anonymous"
    config.ftp_extend_passwd = ""
    config.ftp_extend_folder = "/"
    config.ftp_extend_url = "http://localhost"
    config.ftp_extend_passive = false
  end
end
