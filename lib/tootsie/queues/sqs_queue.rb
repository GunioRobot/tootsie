require 'json'
require 'sqs'
require 'timeout'

module Tootsie

  class SqsQueueCouldNotFindQueueError < Exception; end

  # A queue which uses Amazon's Simple Queue Service (SQS).
  class SqsQueue

    def initialize(queue_name, sqs_service)
      @logger = Application.get.logger
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
      @backoff = 0.5
    end

    def count
      @queue.attributes['ApproximateNumberOfMessages'].to_i
    end

    def push(item)
      retries_left = 5
      begin
        return @queue.create_message(item.to_json)
      rescue SystemExit, Interrupt
        raise
      rescue Exception => exception
        if retries_left > 0
          @logger.warn("Writing queue failed with exception (#{exception.message}), will retry")
          retries_left -= 1
          sleep(0.5)
          retry
        else
          @logger.error("Writing queue failed with exception #{exception.class}: #{exception.message}")
          raise exception
        end
      end
    end

    def pop(options = {})
      item = nil
      loop do
        begin
          message = @queue.message(5)
        rescue SystemExit, Interrupt
          raise
        rescue Exception => exception
          @logger.error("Reading queue failed with exception #{exception.class}: #{exception.message}")
          break unless options[:wait]
          sleep(0.5)
          retry
        end
        if message
          begin
            item = JSON.parse(message.body)
          ensure
            # Always destroy, even if parsing fails
            message.destroy
          end
          @backoff /= 2.0
          break
        else
          @backoff = [@backoff * 0.2, 2.0].min
        end
        break unless options[:wait]
        sleep(@backoff)
      end
      item
    end

  end

end
