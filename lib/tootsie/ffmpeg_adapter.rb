module Tootsie

  class FfmpegAdapter

    def initialize(options = {})
      @logger = Application.get.logger
      @ffmpeg_binary = 'ffmpeg'
      @ffmpeg_arguments = {}
      @ffmpeg_arguments['threads'] = (options[:thread_count] || 1)
      @ffmpeg_arguments['v'] = 1
      if false
        # TODO: Only in newer FFmpeg versions
        @ffmpeg_arguments['xerror'] = true
        @ffmpeg_arguments['loglevel'] = 'verbose'
      end
      @ffmpeg_arguments['y'] = true
    end

    # Transcode a file by taking an input file and writing an output file.
    def transcode(input_filename, output_filename, options = {})
      arguments = @ffmpeg_arguments.dup
      if options[:audio_codec].to_s == 'none'
        arguments['an'] = true
      else
        case options[:audio_codec].try(:to_s)
          when 'aac'
            arguments['acodec'] = 'libfaac'
          when String
            arguments['acodec'] = options[:audio_codec]
        end
        arguments['ar'] = options[:audio_sample_rate] if options[:audio_sample_rate]
        arguments['ab'] = options[:audio_bitrate] if options[:audio_bitrate]
      end
      if options[:video_codec].to_s == 'none'
        arguments['vn'] = true
      else
        case options[:video_codec].try(:to_s)
          when 'h264'
            arguments['vcodec'] = 'libx264'
            arguments['vpre'] = ['medium', 'main']  # TODO: Allow override
            arguments['crf'] = 15                   # TODO: Allow override
            arguments['threads'] = 0
          when String
            arguments['vcodec'] = options[:video_codec]
        end
        arguments['b'] = options[:video_bitrate] if options[:video_bitrate]
        arguments['r'] = options[:video_frame_rate] if options[:video_frame_rate]
        arguments['s'] = "#{options[:width]}x#{options[:height]}" if options[:width] or options[:height]
        arguments['sameq'] = true
      end
      arguments['f'] = options[:format] if options[:format]

      progress, expected_duration = @progress, nil
      result_width, result_height = nil
      run_ffmpeg(input_filename, output_filename, arguments) do |line|
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
            when /Stream.*Video: .*, (\d+)x(\d+)\s/
              unless result_width and result_height
                result_width, result_height = $1.to_i, $2.to_i
              end
          end
          progress.call(elapsed_time, expected_duration) if elapsed_time
        end
      end

      thumbnail_options = options[:thumbnail]
      if thumbnail_options
        thumb_width = thumbnail_options[:width].try(:to_i) || options[:width].try(:to_i)
        thumb_height = thumbnail_options[:height].try(:to_i) || options[:height].try(:to_i)
        if not thumbnail_options[:force_aspect_ratio] and result_width and result_height
          thumb_height = (thumb_width / (result_width / result_height.to_f)).to_i
        end
        at_seconds = thumbnail_options[:at_seconds].try(:to_f)
        at_seconds ||= (expected_duration || 0) * (thumbnail_options[:at_fraction].try(:to_f) || 0.5)
        @logger.info("Getting thumbnail frame (#{thumb_width}x#{thumb_height}) with FFmpeg at #{at_seconds} seconds")
        begin
          run_ffmpeg(input_filename, thumbnail_options[:filename], @ffmpeg_arguments.merge(
            :ss => at_seconds,
            :vcodec => :mjpeg,
            :vframes => 1,
            :an => true,
            :f => :rawvideo,
            :s => "#{thumb_width}x#{thumb_height}"))
        rescue FfmpegAdapterExecutionFailed => e
          @logger.error("Thumbnail rendering failed, ignoring: #{e}")
        end
      end
    end

    attr_accessor :ffmpeg_binary
    attr_accessor :ffmpeg_arguments

    # Output captured from FFmpeg command line tool so far.
    attr_reader :output

    # Progress reporter that implements +call(seconds, total_seconds)+ to record
    # transcoding progress.
    attr_accessor :progress

    private

      def run_ffmpeg(input_filename, output_filename, arguments, &block)
        command_line = @ffmpeg_binary.dup
        command_line << " -i '#{input_filename}' "
        command_line << arguments.map { |k, v|
          case v
            when TrueClass, FalseClass
              "-#{k}"
            when Array
              v.map { |w| "-#{k} '#{w}'" }.join(' ')
            else
              "-#{k} '#{v}'"
          end
        }.join(' ')
        command_line << ' '
        command_line << "'#{output_filename}'"
        CommandRunner.new(command_line).run(&block)
      end

  end

end
