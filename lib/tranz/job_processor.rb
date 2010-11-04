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
          handle_job(job)
        end
      end
      @logger.info "Job processor done"
    end
    
    private
    
      def handle_job(job)
        @logger.info "Begin processing job: #{job.inspect}"
        job.notify!(:event => :started)
        input = Input.new(job.input_url)
        begin
          input.get!
          output = Output.new(job.output_url)
          begin
            thumbnail = Output.new(job.thumbnail_url) if job.thumbnail_url
            begin
              adapter_options = job.transcoding_options.dup
              adapter_options[:thumbnail] = job.thumbnail_options.merge(:filename => thumbnail.file_name) if thumbnail

              elapsed_time = Benchmark.realtime {
                last_notified = nil
                adapter = Tranz::FfmpegAdapter.new(:thread_count => Application.get.configuration.ffmpeg_thread_count)
                adapter.progress = lambda { |seconds, total_seconds|
                  now = Time.now
                  if last_notified.nil? or now - last_notified > 10.seconds
                    last_notified = now
                    job.notify!(
                      :event => :progress,
                      :seconds => seconds,
                      :total_seconds => total_seconds)
                  end
                }
                adapter.transcode(
                  input.file_name,
                  output.file_name,
                  adapter_options)
              }                
              output.content_type = job.transcoding_options[:content_type] if job.transcoding_options[:content_type]
              output.put!(job.output_options)
              
              thumbnail.put!(job.thumbnail_options) if thumbnail
            
              job.notify!(
                :event => :completed,
                :url => output.result_url,
                :time_taken => elapsed_time)
            ensure
              thumbnail.try(:close)
            end
          ensure
            output.close
          end
        ensure
          input.close
        end
      rescue Interrupt
        job.notify!(:event => :failed, :reason => 'Cancelled')
        raise
      rescue Exception => exception
        @logger.error "Job failed with exception #{exception.class}: #{exception}\n" <<
          "#{exception.backtrace.map { |line| "#{line}\n" }.join}"
        if job.retries_left and job.retries_left > 0
          job.retries_left -= 1
          @logger.info "Pushing job back on queue to retry it"
          job.notify!(:event => :failed_will_retry, :reason => exception.message)
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
