require 'sinatra/base'

module Tranz
  
  class WebService < Sinatra::Base
    set :sessions, false
    set :run, false
    
    get '/' do
      404
    end
    
    post '/job' do
      job_data = JSON.parse(request.env["rack.input"].read)
      logger.info "Handling job: #{job_data.inspect}"
      job = Tasks::JobTask.new(job_data)
      unless job.valid?
        halt 400, 'Invalid job specification'
      end
      Application.get.task_manager.schedule(job)
      201
    end
    
    get '/status' do
      queue = Application.get.queue
      {'queue_count' => queue.count}.to_json
    end
    
    private
    
      def logger
        return @logger ||= Application.get.logger
      end
    
  end
  
end
