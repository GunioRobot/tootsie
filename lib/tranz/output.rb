require 'httpclient'
require 's3'

module Tranz
  
  class IncompatibleOutputError < Exception; end
  
  class Output
    
    def initialize(url)
      @url = url
      @temp_file = Tempfile.new('tranz')
      @temp_file.close
      @file_name = @temp_file.path
      @logger = Application.get.logger
    end
    
    # Put data into the output. Options:
    #
    # * +:content_type+ - content type of the stored data.
    #
    def put!(options = {})
      @logger.info("Storing #{@url}")
      case @url
        when /^file:(.*)/
          FileUtils.cp(@temp_file.path, $1)
        when /^s3:.*/
          s3_options = S3.parse_uri(@url)
          bucket_name, path = s3_options[:bucket], s3_options[:key]
          File.open(@temp_file.path, 'r') do |file|
            s3_service = Tranz::Application.get.s3_service
            begin
              object = s3_service.buckets.find(bucket_name).objects.build(path)
              object.acl = s3_options[:acl] || :private
              object.content_type = s3_options[:content_type]
              object.content_type ||= @content_type if @content_type
              object.storage_class = s3_options[:storage_class] || :standard
              object.content = file
              object.save
              @result_url = object.url
            rescue ::S3::Error::NoSuchBucket
              raise IncompatibleOutputError, "Bucket #{bucket_name} not found"
            end
          end
        when /^http(s?):\/\//
          File.open(@temp_file.path, 'wb') do |file|
            HTTPClient.new.get_content(@url) do |chunk|
              file << chunk
            end
          end
        else
          raise IncompatibleOutputError, "Don't know to store output URL: #{@url}"
      end
    end
    
    def close
      @temp_file.unlink
    end
    
    attr_reader :url
    attr_reader :result_url
    attr_reader :file_name
    attr_accessor :content_type
    
  end

end
