Tranz
-----

Tranz is a simple audio/video transcoding application written in Ruby. Tranz uses FFmpeg for transcoding of video and audio and supports Amazon S3 for storage, and Amazon Simple Queue Service for internal job queue management.

Tranz is divided into multiple independent parts:

* Job processor: finds new transcoding jobs and executes them.
* FFmpeg: does the actual transcoding.
* Queue: currently local file-based queues (for testing) and Amazon Simple Queue Service are supported.
* Storage: currently web servers and Amazon S3 are supported.
* Web service: A small RESTful API for managing jobs.

The framework is designed to be easily pluggable, and to let you pick the parts you need to build a custom transcoding service.

The job processor
-----------------

The job processor pops jobs from a queue and processes them. Each job specifies an input, an output, and transcoding parameters. Optionally the job may also specify a notification URL which is invoked to inform the caller about job progress.

Supported inputs at the moment:

* HTTP resource. Currently only public (non-authenticated) resources are supported.
* Amazon S3 bucket resource. S3 buckets must have the appropriate ACLs so that Tranz can read the files; if the input file is not public, Tranz must be run with an AWS access key that is granted read access to the file.

Supported outputs:

* HTTP resource. The encoded file will be `POST`ed to a URL.
* Amazon S3 bucket resource. Tranz will need write permissions to any S3 buckets.

If a notification URL is provided, events will be sent to it using `POST` requests. There are three types of events, indicated by the `event` parameter:

* `started`: The job was started.
* `complete`: The job was complete. The parameter `url` will specify the completed file, and the parameter `time_taken` will count the number of seconds that the job took to complete.
* `failed`: The job failed. The parameter `reason` will contain a textual explanation for the failure.

FFmpeg
------

FFmpeg is invoked for each job to perform the transcoding. FFmpeg is abstracted behind set of generic options specifying format, codecs, bit rate and so on.

Web service
-----------

The web service is a small Sinatra app that supports job control methods. Currently defined API:

* `/job`: POST a job to this action to schedule a job. Returns 201 if the job was created. Parameters:

  * `input_url`: URL to input file, either an HTTP URL or one with the format `s3:bucketname/path/to/file`.
  * `output_url`: URL to output resource, either an HTTP URL which accepts POSTs, or a URL with format `s3:bucketname/path/to/file`.
  * `output_options[s3_acl]`: For S3 outputs, one of `private` (default), `public-read`, `public-read-write` or `authenticated-read`.
  * `output_options[s3_storage_class]`: For S3, either `standard` (default) or `reduced_redundancy`.
  * `thumbnail_url`: URL to output resource, either an HTTP URL which accepts POSTs, or a URL with format `s3:bucketname/path/to/file`.
  * `thumbnail_options[s3_acl]`: Same as for `output_options`.
  * `thumbnail_options[s3_storage_class]`: Same as for `output_options`.
  * `thumbnail_options[width]`: Desired width of thumbnail, defaults to output width.
  * `thumbnail_options[height]`: Desired height of thumbnail, defaults to output height.
  * `thumbnail_options[at_seconds]`: Desired point (in seconds) at which the thumbnail frame should be captured. Defaults to 50% into stream.
  * `thumbnail_options[at_fraction]`: Desired point (in percentage) at which the thumbnail frame should be captured. Defaults to 50% into stream.
  * `thumbnail_options[force_aspect_ratio]`: If `true`, force aspect ratio; otherwise aspect is preserved when computing dimensions.
  * `transcoding_options[audio_sample_rate]`: Audio sample rate, in herz.
  * `transcoding_options[audio_bitrate]`: Audio bitrate, in bits per second.
  * `transcoding_options[audio_codec]`: Audio codec name, eg. `mp4`.
  * `transcoding_options[video_frame_rate]`: video frame rate, in herz.
  * `transcoding_options[video_bitrate]`: video bitrate, in bits per second.
  * `transcoding_options[video_codec]`: video codec name, eg. `mp4`.
  * `transcoding_options[width]`: desired video frame width in pixels.
  * `transcoding_options[height]`: desired video frame height in pixels.
  * `transcoding_options[format]`: File format.
  * `transcoding_options[content_type]`: Content type of resultant file. Tranz will not be able to guess this at the moment.
  * `notification_url`: Optional notification URL. Progress will be reported using POSTs.

Current limitations
-------------------

* Daemon supports only one job processor thread at a time.
* Transcoding options are incomplete.
* No client access control; anyone can submit jobs.

Requirements
------------

* Ruby 1.8.7 or later.
* FFmpeg.
* Bundler.

Installation
------------

* Fetch Git repositroy: `git clone git@github.com:origo/tranz.git`.
* Install Bundler with `gem install bundler`.
* Install dependencies with `cd tranz; bundle install`.

Running
-------

Start the job processor with `bin/job_processor start`.

Start the web service with `bin/web_service start`.

Jobs may now be posted to the web service API. For example:

    $ cat << END | curl -d @- http://localhost:9090/job
    input_url=http://example.com/test.3gp&
    output_url=s3:mybucket/test.mp4&
    output_options[s3_acl]=public_read&
    notification_url=http://example.com/transcoder_notification&
    transcoding_options[audio_sample_rate]=44100&
    transcoding_options[audio_bitrate]=64000&
    transcoding_options[format]=flv&
    transcoding_options[content_type]=video/x-flv
    END

License
-------

Copyright (c) 2010 Alexander Staubo
 
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
 
The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
