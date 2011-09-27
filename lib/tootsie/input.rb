require 'httpclient'
require 'tempfile'
require 's3'

module Tootsie

  class InputNotFound < Exception; end

  class Input

    def initialize(url)
      @url = url
      @temp_file = Tempfile.new('tootsie')
      @temp_file.close
      @file_name = @temp_file.path
      @logger = Application.get.logger
    end

    def get!
      @logger.info("Fetching #{@url} as #{@temp_file.path}")
      case @url
        when /^file:(.*)/
          @file_name = $1
          raise InputNotFound, @url unless File.exist?(@file_name)
        when /^s3:.*$/
          s3_options = S3.parse_uri(@url)
          bucket_name, path = s3_options[:bucket], s3_options[:key]
          s3_service = Tootsie::Application.get.s3_service
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
            f << response.body
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
