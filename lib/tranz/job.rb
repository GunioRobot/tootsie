require 'json'

module Tranz
  
  class Job
    
    def initialize(attributes = {})
      attributes = attributes.with_indifferent_access
      @input_url = attributes[:input_url]
      @output_url = attributes[:output_url]
      @output_options = (attributes[:output_options] || {}).with_indifferent_access
      @thumbnail_url = attributes[:thumbnail_url]
      @thumbnail_options = (attributes[:thumbnail_options] || {}).with_indifferent_access
      @notification_url = attributes[:notification_url]
      @transcoding_options = (attributes[:transcoding_options] || {}).with_indifferent_access
      @retries_left = attributes[:retries_left] || 5
      @access_key = attributes[:access_key]
      @created_at = Time.now
    end
    
    def valid?
      return (@input_url and @output_options and @transcoding_options ? true : false)
    end
    
    def to_json
      return {
        :input_url => @input_url,
        :output_url => @output_url,
        :output_options => @output_options,
        :thumbnail_url => @thumbnail_url,
        :thumbnail_options => @thumbnail_options,
        :notification_url => @notification_url,
        :transcoding_options => @transcoding_options,
        :retries_left => @retries_left,
        :access_key => @access_key,
      }.to_json        
    end
    
    # Notify the caller of this job with some message.
    def notify!(message)
      notification_url = self.notification_url
      if notification_url
        message = message.merge(:signature => Client.generate_signature(self.access_key)) if self.access_key
        message = message.stringify_keys
        Application.get.logger.info "Notifying #{notification_url} with message: #{message.inspect}"
        HTTPClient.new.post(notification_url, message)
      end
    end
    
    attr_accessor :input_url
    attr_accessor :output_url
    attr_accessor :output_options
    attr_accessor :notification_url
    attr_accessor :transcoding_options
    attr_accessor :thumbnail_url
    attr_accessor :thumbnail_options
    attr_accessor :retries_left
    attr_accessor :created_at
    attr_accessor :access_key
    
  end
  
end
