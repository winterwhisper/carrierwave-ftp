require 'carrierwave'
require 'carrierwave/storage/ftp/ex_sftp'

module CarrierWave
  module Storage
    class SFTP < Abstract
      def store!(file)
        f = CarrierWave::Storage::SFTP::File.new(uploader, self, uploader.store_path)
        f.store(file)
        f
      end

      def retrieve!(identifier)
        CarrierWave::Storage::SFTP::File.new(uploader, self, uploader.store_path(identifier))
      end

      class File
        attr_reader :path

        def initialize(uploader, base, path)
          @uploader, @base, @path = uploader, base, path
        end

        def store(file)
          connection do |sftp|
            sftp.mkdir_p!(::File.dirname full_path)
            sftp.upload!(file.path, full_path)
          end
        end

        def url
          "#{@uploader.sftp_url}/#{path}"
        end

        def filename(options = {})
          url.gsub(/.*\/(.*?$)/, '\1')
        end

        def size
          size = nil

          connection do |sftp|
            #size = sftp.stat!(full_path).size
            size = sftp.stat(full_path).respond_to?(:size) ? sftp.stat!(full_path).size : 0
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
          connection do |sftp|
            sftp.remove!(full_path)
          end
        rescue
        end

        private

        def full_path
          "#{@uploader.sftp_folder}/#{path}"
        end

        def file
          require 'net/http'
          url = URI.parse(url)
          req = Net::HTTP::Get.new(url.path)
          Net::HTTP.start(url.host, url.port) do |http|
            http.request(req)
          end
        end

        def connection
          sftp = Net::SFTP.start(@uploader.sftp_host, @uploader.sftp_user, @uploader.sftp_options)
          yield sftp
          sftp.close_channel
        end
      end
    end
  end
end

CarrierWave::Storage.autoload :SFTP, 'carrierwave/storage/sftp'

class CarrierWave::Uploader::Base
  add_config :sftp_host
  add_config :sftp_user
  add_config :sftp_options
  add_config :sftp_folder
  add_config :sftp_url

  configure do |config|
    config.storage_engines[:sftp] = "CarrierWave::Storage::SFTP"
    config.sftp_host = "localhost"
    config.sftp_user = "anonymous"
    config.sftp_options = {}
    config.sftp_folder = ""
    config.sftp_url = "http://localhost"
  end
end
