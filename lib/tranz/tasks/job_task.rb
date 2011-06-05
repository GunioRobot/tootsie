module Tranz
  module Tasks
    
    class JobTask
    
      DEFAULT_MAX_RETRIES = 5
      
      PROGRESS_NOTIFICATION_INTERVAL = 10.seconds
    
      VALID_TYPES = %w(video audio).freeze
    
      def initialize(attributes = {})
        attributes = attributes.with_indifferent_access
        @type = attributes[:type].to_s
        @retries_left = attributes[:retries_left] || DEFAULT_MAX_RETRIES
        @access_key = attributes[:access_key]
        @created_at = Time.now
        @notification_url = attributes[:notification_url]
        @params = attributes[:params]
        @logger = Application.get.logger
        @use_tasks_for_notifications = false  # TODO: Disabled for now, SQS does not preserve order
      end
    
      def valid?
        return @type && VALID_TYPES.include?(@type)
      end
    
      def execute!
        @logger.info("Begin processing job: #{attributes.inspect}")
        notify!(:event => :started)
        begin
          result = nil
          elapsed_time = Benchmark.realtime {
            next_notify = Time.now + PROGRESS_NOTIFICATION_INTERVAL
            processor = Processors.const_get("#{@type.camelcase}Processor").new(@params)
            result = processor.execute! { |progress_data|
              if Time.now >= next_notify
                notify!(progress_data.merge(:event => :progress))
                next_notify = Time.now + PROGRESS_NOTIFICATION_INTERVAL
              end
            }
          }
          result ||= {}
          notify!({
            :event => :completed,
            :time_taken => elapsed_time
          }.merge(result))
        rescue Interrupt
          @logger.error "Job interrupted"
          notify!(:event => :failed, :reason => 'Cancelled')
          raise
        rescue Exception => exception
          @logger.error "Job failed with exception #{exception.class}: #{exception}\n" <<
            "#{exception.backtrace.map { |line| "#{line}\n" }.join}"
          if @retries_left > 0
            @retries_left -= 1
            @logger.info "Pushing job back on queue to retry it"
            notify!(:event => :failed_will_retry, :reason => exception.message)
            Application.get.task_manager.schedule(self)
          else
            @logger.error "No more retries for job, marking as failed"
            notify!(:event => :failed, :reason => exception.message)
          end
        else
          @logger.info "Completed job #{attributes.inspect}"
        end
      end
    
      # Notify the caller of this job with some message.
      def notify!(message)
        notification_url = @notification_url
        if notification_url
          message = message.merge(:signature => Client.generate_signature(@access_key)) if @access_key
          message = message.stringify_keys          
          if @use_tasks_for_notifications
            Application.get.task_manager.schedule(
              Tasks::NotifyTask.new(:url => notification_url, :message => message))
          else
            @logger.info "Notifying #{notification_url} with message: #{message}"
            HTTPClient.new.post(notification_url, message)
          end
        end
      end
    
      def attributes
        return {
          :type => @type,
          :notification_url => @notification_url,
          :retries_left => @retries_left,
          :access_key => @access_key,
          :params => @params
        }
      end
    
      attr_accessor :retries_left
      attr_accessor :created_at
      attr_accessor :access_key
      attr_accessor :notification_url
      attr_accessor :params
      attr_accessor :type
          
    end

  end  
end
