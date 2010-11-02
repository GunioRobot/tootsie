module Tranz

  class FfmpegAdapterException < Exception; end
  class FfmpegAdapterExecutionFailed < FfmpegAdapterException; end
  
  class FfmpegAdapter
    
    def initialize(options = {})
      @logger = options[:logger]
      @ffmpeg_binary = 'ffmpeg'
      @ffmpeg_arguments = {}
      @ffmpeg_arguments['threads'] = (options[:thread_count] || 1)
    end
    
    # Transcode a file by taking an input file and writing an output file.
    def transcode(input_filename, output_filename, options = {})
      @output = ''
      arguments = @ffmpeg_arguments.dup
      if options[:audio_codec].to_s == 'none'
        arguments['an'] = true
      else
        arguments['acodec'] = options[:audio_codec] if options[:audio_codec]
        arguments['ar'] = options[:audio_sample_rate] if options[:audio_sample_rate]
        arguments['ab'] = options[:audio_bitrate] if options[:audio_bitrate]
      end
      if options[:video_codec].to_s == 'none'
        arguments['vn'] = true
      else
        arguments['vcodec'] = options[:video_codec] if options[:video_codec]
        arguments['b'] = options[:video_bitrate] if options[:video_bitrate]
        arguments['r'] = options[:video_frame_rate] if options[:video_frame_rate]
        arguments['s'] = "#{options[:width]}x#{options[:height]}" if options[:width] or options[:height]
        arguments['sameq'] = true
      end
      arguments['f'] = options[:format] if options[:format]
      arguments['xerror'] = true
      arguments['y'] = true
      arguments['loglevel'] = 'verbose'
      arguments['v'] = 1
      command_line = "#{@ffmpeg_binary} "
      command_line << "-i '#{input_filename}' "
      command_line << arguments.map { |k, v|
        (v.is_a?(TrueClass) or v.is_a?(FalseClass)) ? "-#{k}" : "-#{k} '#{v}'"
      }.join(' ')
      command_line << ' '
      command_line << "'#{output_filename}' 2>&1"

      progress, expected_duration = @progress, nil
      IO.popen(command_line, 'r') do |output|
        output.each_line do |line|
          if progress
            case line
              when /^\s*Duration: (\d+):(\d+):(\d+)\./
                unless expected_duration
                  hours, minutes, seconds = $1.to_i, $2.to_i, $3.to_i
                  expected_duration = seconds + minutes * 60 + hours * 60 * 60
                end
              when /^frame=.* time=(\d+)\./
                if expected_duration
                  elapsed_time = $1.to_i
                end
            end
            progress.call(elapsed_time, expected_duration) if elapsed_time
          end
          @output << line
          @logger.info("[ffmpeg] #{line.strip}") if @logger
        end
      end

      status = $?
      if status.exited?       
        raise FfmpegAdapterExecutionFailed, "FFmpeg failed with exit code #{status.exitstatus}" if status.exitstatus != 0
      elsif status.stopped?
        raise FfmpegAdapterExecutionFailed, "FFmpeg stopped unexpectedly with signal #{status.stopsig}"
      elsif status.signaled?
        raise FfmpegAdapterExecutionFailed, "FFmpeg died unexpectedly by signal #{status.termsig}"
      else
        raise FfmpegAdapterExecutionFailed, "FFmpeg died unexpectedly"
      end
    end
    
    attr_accessor :ffmpeg_binary
    attr_accessor :ffmpeg_arguments
    attr_accessor :logger
    
    # Output captured from FFmpeg command line tool so far.
    attr_reader :output

    # Progress reporter that implements +call(seconds, total_seconds)+ to record
    # transcoding progress.
    attr_accessor :progress

  end
    
end
