require 'time'

module Tranz
  module Processors
  
    class ImageProcessor
    
      def initialize(params = {})
        @input_url = params[:input_url]
        @versions = [params[:versions] || {}].flatten
        @logger = Application.get.logger
      end
    
      def valid?
        return @input_url && !@versions.blank?
      end
    
      def params
        return {
          :input_url => @input_url,
          :versions => @versions
        }
      end
    
      def execute!(&block)
        result = {:outputs => []}
        input, output = Input.new(@input_url), nil
        begin
          input.get!
          begin
            versions.each_with_index do |version_options, version_index|
              version_options = version_options.with_indifferent_access
              @logger.info("Handling version: #{version_options.inspect}")
              
              output = Output.new(version_options[:target_url])
              begin
                result[:metadata] ||= begin
                  metadata = {}
                  Application.get.run_command('exiv2 -pt :file', :file => input.file_name, :ignore_exit_code => true) do |line|
                    parse_exiv2_line(line, metadata)
                  end
                  Application.get.run_command('exiv2 -pi :file', :file => input.file_name, :ignore_exit_code => true) do |line|
                    parse_exiv2_line(line, metadata)
                  end
                  Application.get.run_command('exiv2 -px :file', :file => input.file_name, :ignore_exit_code => true) do |line|
                    parse_exiv2_line(line, metadata)
                  end
                  metadata = Hash[*metadata.entries.map { |key, values|
                    [key, values.length > 1 ? values : values.first]
                  }.flatten(1)]
                  metadata
                end
                
                original_width, original_height = nil, nil
                Application.get.run_command("identify -format '%w %h' :file", :file => input.file_name) do |line|
                  if line =~ /(\d+) (\d+)/
                    original_width, original_height = $1.to_i, $2.to_i
                  end
                end
                unless original_width and original_height
                  raise "Unable to determine dimensions of input image"
                end
                original_aspect = original_height / original_width.to_f
                
                new_width, new_height = version_options[:width], version_options[:height]
                if new_width
                  new_height ||= (new_width * original_aspect).ceil
                elsif new_height
                  new_width ||= (new_height / original_aspect).ceil
                else
                  new_width, new_height = original_width, original_height
                end

                scale_width, scale_height = new_width, new_height
                scale = (version_options[:scale] || 'down').to_sym
                case scale
                  when :up, :none
                    # Do nothing
                  when :down
                    if scale_width > original_width
                      scale_width = original_width
                      scale_height = (scale_width * original_aspect).ceil
                    elsif scale_height > original_height
                      scale_height = original_height
                      scale_width = (scale_height / original_aspect).ceil
                    end
                  when :fit
                    if (scale_width * original_aspect).ceil < new_height
                      scale_height = new_height
                      scale_width = (new_height / original_aspect).ceil
                    elsif (scale_height / original_aspect).ceil < new_width
                      scale_width = new_width
                      scale_height = (scale_width * original_aspect).ceil
                    end
                end
                
                convert_command = "convert"
                convert_options = {:input_file => input.file_name}
                case version_options[:format]
                  when 'png', 'jpeg', 'gif'
                    convert_options[:output_file] = "#{version_options[:format]}:#{output.file_name}"
                  else
                    convert_options[:output_file] = output.file_name
                end
                if scale != :none
                  convert_command << " -resize :resize"
                  convert_options[:resize] = "#{scale_width}x#{scale_height}"
                end
                if version_options[:crop]
                  convert_command << " -gravity center -crop :crop"
                  convert_options[:crop] = "#{new_width}x#{new_height}+0+0"
                end
                if version_options[:strip_metadata]
                  convert_command << " +profile :remove_profiles -set comment ''"
                  convert_options[:remove_profiles] = "8bim,iptc,xmp,exif"
                end

                convert_command << " -quality #{((version_options[:quality] || 1.0) * 100).ceil}%"
                
                convert_command << " :input_file :output_file"
                Application.get.run_command(convert_command, convert_options)
                
                if version_options[:format] == 'png'
                  Tempfile.open('tranz') do |file|
                    # TODO: Make less sloppy
                    file.write(File.read(output.file_name))
                    file.close
                    Application.get.run_command('pngcrush :input_file :output_file',
                      :input_file => file.path, :output_file => output.file_name)
                  end
                end
                
                output.content_type = version_options[:content_type] if version_options[:content_type]
                output.content_type ||= case version_options[:format]
                  when 'jpeg' then 'image/jpeg'
                  when 'png' then 'image/png'
                  when 'gif' then 'image/gif'
                end
                output.put!
                result[:outputs] << {:url => output.result_url}
              ensure
                output.close
              end
            end
          end
        ensure
          input.close
        end
        result
      end
    
      attr_accessor :input_url
      attr_accessor :versions
      
      private
      
        def parse_exiv2_line(line, hash)
          if line =~ /^([^\s]+)\s+([^\s]+)\s+\d+  (.*)$/
            key, type, value = $1, $2, $3
            case type
              when 'Short', 'Long'
                value = value.to_i
              when 'Date'
                value = Time.parse(value)
            end
            (hash[key] ||= []) << value
          end
        end
    
    end

  end  
end
