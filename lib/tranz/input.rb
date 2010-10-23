require 'httpclient'
require 'tempfile'

module Tranz

  class InputNotFound < Exception; end

  class Input

    def initialize(url)
      @url = url
      temp_file = Tempfile.new('tranz')
      @file_name = temp_file.path
      temp_file.close
    end

    def get!
      case @url
        when /^s3:([^\/]+)\/+(.+)$/
          bucket_name, path = $1, $2
          begin
            AWS::S3::S3Object.find(path, bucket_name).value
          rescue AWS::S3::NoSuchKey
            raise InputNotFound, @url
          end
        when /http(s?):\/\//
          response = HTTPClient.new.get(@url)
          File.open(@file_name, 'wb') { |f| f << response.body.content }
        else
          raise ArgumentError, "Don't know to handle URL: #{@url}"
      end
    end

    def close
      FileUtils.rm(@file_name) rescue nil
    end

    attr_reader :url
    attr_reader :file_name

  end

end
