# encoding: utf-8

require 'logger'
require 'set'
require 'timeout'

class Spawner

  def initialize(options = {})
    @num_children = options[:num_children] || 1
    @pids = Set.new
    @logger = options[:logger]
    @terminating = false
    @parent = true
  end

  def on_spawn(&block)
    @on_spawn = block
  end

  def run(&block)
    loop do
      unless @terminating
        while @pids.length < @num_children
          pid = Process.fork
          if pid
            # In parent process
            @pids << pid
            logger.info("Child PID=#{pid} spawned")
          else
            # In child process
            @parent = false
            @on_spawn.call
            exit(0)
          end
        end
      end
      wait_for_children
      break if @terminated and @pids.empty?
    end
  end

  def wait_for_children
    pid = Process.waitpid(-1)
    if pid
      status = $?
      if status.exited?
        if status.exitstatus == 0
          logger.info("Child PID=#{pid} exited normally")
        else
          logger.info("Child PID=#{pid} exited unexpectedly with exit code #{status.exitstatus}")
        end
      elsif status.stopped?
        logger.info("Child PID=#{pid} stopped unexpectedly with signal #{status.stopsig}")
      elsif status.signaled?
        logger.info("Child PID=#{pid} died unexpectedly by signal #{status.termsig}")
      else
        logger.info("Child PID=#{pid} died unexpectedly")
      end
      @pids.delete(pid)
    end
  end

  def terminate
    if @parent
      logger.info("Parent terminating, will terminate all child PIDs")
      @terminating = true
      @pids.each do |pid|
        logger.info("Terminating child PID=#{pid}")
        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH
          # Ignore
        end
      end
      begin
        timeout(5) do
          while @pids.any?
            sleep(0.5)
            wait_for_children
          end
        end
      rescue Timeout::Error
        logger.error("Timed out waiting for children, killing them")
        @pids.each do |pid|
          logger.info("Killing child PID=#{pid}")
          begin
            Process.kill("KILL", pid)
          rescue Errno::ESRCH
            # Ignore
          end
        end
      end
    end
  end

  attr_reader :logger

end
