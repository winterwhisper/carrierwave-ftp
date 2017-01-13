require 'carrierwave'
require 'carrierwave/storage/ftp_extend/ex_sftp'

module CarrierWave
  module Storage
    class SFTPExtend < Abstract
      def store!(file)
        f = CarrierWave::Storage::SFTPExtend::File.new(uploader, self, uploader.store_path)
        f.store(file)
        f
      end

      def retrieve!(identifier)
        CarrierWave::Storage::SFTPExtend::File.new(uploader, self, uploader.store_path(identifier))
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
          "#{@uploader.sftp_extend_url}/#{path}"
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

        def use_ssl?
          @uploader.sftp_extend_url.start_with?('https')
        end

        def full_path
          "#{@uploader.sftp_extend_folder}/#{path}"
        end

        def file
          require 'net/http'
          url = URI.parse(self.url)
          req = Net::HTTP::Get.new(url.path)
          Net::HTTP.start(url.host, url.port, :use_ssl => use_ssl?) do |http|
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

CarrierWave::Storage.autoload :SFTPExtend, 'carrierwave/storage/sftp_extend'

class CarrierWave::Uploader::Base
  add_config :sftp_extend_host
  add_config :sftp_extend_user
  add_config :sftp_extend_options
  add_config :sftp_extend_folder
  add_config :sftp_extend_url

  configure do |config|
    config.storage_engines[:sftp_extend] = "CarrierWave::Storage::SFTPExtend"
    config.sftp_extend_host = "localhost"
    config.sftp_extend_user = "anonymous"
    config.sftp_extend_options = {}
    config.sftp_extend_folder = ""
    config.sftp_extend_url = "http://localhost"
  end
end
