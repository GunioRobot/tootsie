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
        arguments['f'] = options[:format] if options[:format]
        arguments['s'] = "#{options[:width]}x#{options[:height]}" if options[:width] or options[:height]
        arguments['sameq'] = true
      end
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
      IO.popen(command_line, 'r') do |output|
        output.each_line do |line|
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
    attr_reader :output

  end
    
end
