require 'json'
require 'sqs'
require 'timeout'

module Tranz
  
  class SqsQueueCouldNotFindQueueError < Exception; end

  # A queue which uses Amazon's Simple Queue Service (SQS).
  class SqsQueue
    
    def initialize(queue_name, sqs_service)
      @sqs_service = sqs_service
      @queue = @sqs_service.queues.find_first(queue_name)
      unless @queue
        @sqs_service.queues.create(queue_name)
        begin
          timeout(5) do
            while not @queue
              sleep(0.5)
              @queue = @sqs_service.queues.find_first(queue_name)
            end
          end
        rescue Timeout::Error
          raise SqsQueueCouldNotFindQueueError
        end
      end
    end
    
    def push(job)
      @queue.create_message(job.to_json)
    end
    
    def pop(options = {})
      loop do
        message = @queue.message(5)
        if message
          job_data = JSON.parse(message.body)
          message.destroy
          return Job.new(job_data)
        end
        if options[:wait]
          sleep(1.0)
        else
          return nil
        end
      end
    end
    
  end
  
end
