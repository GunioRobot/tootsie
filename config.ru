require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tranz'
require 'tranz/web_service'

ENV['RACK_ENV'] ||= 'development'

set :environment, ENV['RACK_ENV'].to_sym

Tranz::Application.new(:environment => ENV['RACK_ENV'], :logger => Logger.new("./log/#{ENV['RACK_ENV']}.log"))
Tranz::Application.get.configure!
Thread.new { Tranz::Application.get.task_manager.run! } if ENV['RACK_ENV'] == 'development'
run Tranz::WebService
