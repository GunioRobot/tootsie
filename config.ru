require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tootsie'
require 'tootsie/web_service'

ENV['RACK_ENV'] ||= 'development'

set :environment, ENV['RACK_ENV'].to_sym

Tootsie::Application.new(:environment => ENV['RACK_ENV'], :logger => Logger.new("./log/#{ENV['RACK_ENV']}.log"))
Tootsie::Application.get.configure!
Thread.new { Tootsie::Application.get.task_manager.run! } if ENV['RACK_ENV'] == 'development'
run Tootsie::WebService
