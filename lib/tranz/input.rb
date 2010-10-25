require 'httpclient'
require 'tempfile'
require 's3'

module Tranz

  class InputNotFound < Exception; end

  class Input

    def initialize(url)
      @url = url
      @temp_file = Tempfile.new('tranz')
      @temp_file.close
      @file_name = @temp_file.path
    end

    def get!
      case @url
        when /^s3:([^\/]+)\/+(.+)$/
          bucket_name, path = $1, $2
          s3_service = Tranz::Application.get.s3_service
          begin
            File.open(@temp_file.path, 'wb') do |f|
              f << s3_service.buckets.find(bucket_name).objects.find(path).content
            end
          rescue ::S3::Error::NoSuchBucket, ::S3::Error::NoSuchKey
            raise InputNotFound, @url
          end
        when /http(s?):\/\//
          response = HTTPClient.new.get(@url)
          File.open(@temp_file.path, 'wb') do |f|
            f << response.body.content
          end
        else
          raise ArgumentError, "Don't know to handle URL: #{@url}"
      end
    end

    def close
      @temp_file.unlink
    end

    attr_reader :url
    attr_reader :file_name

  end

end
