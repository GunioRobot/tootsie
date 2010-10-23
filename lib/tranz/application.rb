require 's3'
require 'sqs'

module Tranz
  
  class Application
    
    def initialize(options = {})
      @@instance = self
      @environment = options[:environment] || :development
      @logger = options[:logger] || Logger.new($stdout)
      @configuration = Configuration.new
    end
    
    def configure!
      @configuration.load_from_file(File.join(Dir.pwd, "config/#{@environment}.yml"))
      @queue = Tranz::SqsQueue.new(@configuration.sqs_queue_name, sqs_service)
      @processor = JobProcessor.new(@queue)
      @web_service = WebService.new
    end
    
    def s3_service
      return @s3_service ||= ::S3::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end

    def sqs_service
      return @sqs_service ||= ::Sqs::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end
    
    def run_web_service!
      WebService.run!(
        :host => @configuration.web_service_host,
        :port => @configuration.web_service_port,
        :handler => @configuration.web_service_handler)
    end
    
    class << self
      def get
        @@instance
      end
    end
    
    attr_accessor :environment
    
    attr_reader :configuration
    attr_reader :processor
    attr_reader :web_service
    attr_reader :queue
    attr_reader :logger
    
  end
  
end
