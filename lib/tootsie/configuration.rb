module Tootsie

  class Configuration

    def initialize
      @web_service_host = 'localhost'
      @web_service_port = 9090
      @web_service_handler = 'thin'
      @ffmpeg_thread_count = 1
      @sqs_queue_name = 'tootsie'
    end

    def load_from_file(file_name)
      config = (YAML.load(File.read(file_name)) || {}).with_indifferent_access
      [:aws_access_key_id, :aws_secret_access_key, :web_service_host,
        :web_service_port, :web_service_handler, :ffmpeg_thread_count,
        :sqs_queue_name].each do |key|
        if config.include?(key)
          value = config[key]
          value = $1.to_i if value =~ /\A\s*(\d+)\s*\z/
          instance_variable_set("@#{key}", value)
        end
      end
    end

    attr_accessor :aws_access_key_id
    attr_accessor :aws_secret_access_key
    attr_accessor :web_service_host
    attr_accessor :web_service_port
    attr_accessor :web_service_handler
    attr_accessor :ffmpeg_thread_count
    attr_accessor :sqs_queue_name

  end

end
