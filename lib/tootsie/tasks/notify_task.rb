module Tootsie
  module Tasks
    
    class NotifyTask
    
      def initialize(attributes = {})
        attributes = attributes.with_indifferent_access
        @url = attributes[:url]
        @message = attributes[:message]
      end
    
      def execute!
        Application.get.logger.info "Notifying #{@url} with message: #{@message.inspect}"
        HTTPClient.new.post(@url, @message)
      end
      
      def attributes
        {:url => @url, :message => @message}
      end
    
      attr_accessor :url
      attr_accessor :message
    
    end

  end  
end
