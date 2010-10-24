Tranz
-----

Tranz is a simple transcoding application written in Ruby. Tranz uses FFmpeg for transcoding of video and audio, uses Amazon S3 (optionally) for storage, and Amazon SQS (optionally) for internal job queue management.

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

    $ cat << END | curl -d @- -vs http://localhost:9090/job
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
