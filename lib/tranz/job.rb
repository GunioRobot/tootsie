require 'json'

module Tranz
  
  class Job
    
    def initialize(attributes = nil)
      @attributes = {}.with_indifferent_access
      @attributes.merge!(attributes) if attributes
      @attributes[:transcoding_options] ||= {}.with_indifferent_access
      @attributes[:output_options] ||= {}.with_indifferent_access
      @attributes[:retries_left] ||= 5
      @attributes[:created_at] ||= Time.now
    end
    
    def valid?
      return false unless
        @attributes[:input_url] and
        @attributes[:output_options] and
        @attributes[:transcoding_options]
      return true
    end
    
    def to_json
      return @attributes.to_json
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
    
    def method_missing(name, *args, &block)
      if name =~ /(.*)=$/
        key = $1
        if @attributes.include?($1)
          @attributes[key] = args.first
          return
        end
      end
      if @attributes.include?(name.to_s) and not block
        return @attributes[name]
      end
      super
    end
    
    attr_accessor :access_key
    
  end
  
end