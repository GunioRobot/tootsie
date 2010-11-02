require 'sinatra/base'

module Tranz
  
  class WebService < Sinatra::Base
    set :sessions, false
    set :run, false
    
    get '/' do
      404
    end
    
    post '/job' do
      logger.info "Handling job: #{params.inspect}"
      job = Job.new(params)
      unless job.valid?
        halt 400, 'Invalid job specification'
      end
      Application.get.queue.push(job)
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
