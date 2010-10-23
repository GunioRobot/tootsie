require 'httpclient'
require 'uri'
require 'benchmark'

module Tranz
  
  class JobProcessor
    
    def initialize(queue)
      @queue = queue
      @logger = Application.get.logger
    end
    
    def run!
      @logger.info "Ready to process jobs"
      loop do
        job = @queue.pop(:wait => true)
        if job
          @logger.info "Begin processing job: #{job.inspect}"
          begin
            job.notify!(:event => :started)
            input = Input.new(job.input_url)
            begin
              input.get!
              output = Output.new(job.output_url)
              begin
                elapsed_time = Benchmark.realtime {
                  adapter = Tranz::FfmpegAdapter.new(
                    :logger => @logger,
                    :thread_count => Application.get.configuration.ffmpeg_thread_count)
                  adapter.transcode(
                    input.file_name,
                    output.file_name,
                    job.transcoding_options)
                }                
                output.content_type = job.transcoding_options[:content_type] if job.transcoding_options[:content_type]
                output.put!(job.output_options || {})
                
                job.notify!(
                  :event => :completed,
                  :url => output.result_url,
                  :time_taken => elapsed_time)
              ensure
                output.close
              end
            ensure
              input.close
            end
          rescue Interrupt
            job.notify!(:event => :failed, :reason => 'Cancelled')
          rescue Exception => exception
            @logger.error "Job failed with exception #{exception.class}: #{exception}"
            if job.retries_left and job.retries_left > 0
              job.retries_left -= 1
              @logger.info "Pushing job back on queue to retry it"
              @queue.push(job)
            else
              @logger.error "No more retries for job, marking as failed"
              job.notify!(:event => :failed, :reason => exception.message)
            end
          else
            @logger.info "Completed job #{job.inspect}"
          end
        end
      end
      @logger.info "Job processor done"
    end
    
  end
  
end
