require 's3'
require 'sqs'

module Tranz

  class CommandExecutionFailed < Exception; end
    
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
      @task_manager = TaskManager.new(@queue)
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
    
    def run_command(command_line, options = {}, &block)
      options = options.with_indifferent_access
      command_line.gsub!(/(^|\s):(\w+)/) do
        pre, key, all = $1, $2, $~[0]
        if options.include?(key)
          value = options[key]
          value = "'#{value}'" if value =~ /\s/
          "#{pre}#{value}"
        else
          all
        end
      end
      command_line = "#{command_line} 2>&1"
      @logger.info("Running command: #{command_line}")
      IO.popen(command_line, "r:#{options[:output_encoding] || 'utf-8'}") do |output|
        output.each_line do |line|
          @logger.info("[Command output] #{line.strip}")
          yield line if block_given?
        end
      end
      status = $?
      if status.exited?
        if status.exitstatus != 0
          if options[:ignore_exit_code]
            false
          else
            raise CommandExecutionFailed, "Command failed with exit code #{status.exitstatus}: #{command_line}"
          end
        end
      elsif status.stopped?
        raise CommandExecutionFailed, "Command stopped unexpectedly with signal #{status.stopsig}: #{command_line}"
      elsif status.signaled?
        raise CommandExecutionFailed, "Command died unexpectedly by signal #{status.termsig}: #{command_line}"
      else
        raise CommandExecutionFailed, "Command died unexpectedly: #{command_line}"
      end
      true
    end
    
    class << self
      def get
        @@instance
      end
    end
    
    attr_accessor :environment
    
    attr_reader :configuration
    attr_reader :task_manager
    attr_reader :web_service
    attr_reader :queue
    attr_reader :logger
    
  end
  
end
