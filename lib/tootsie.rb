require 'active_support/core_ext/hash'

require 'tootsie/application'
require 'tootsie/client'
require 'tootsie/configuration'
require 'tootsie/command_runner'
require 'tootsie/daemon'
require 'tootsie/spawner'
require 'tootsie/ffmpeg_adapter'
require 'tootsie/image_metadata_extractor'
require 'tootsie/input'
require 'tootsie/task_manager'
require 'tootsie/tasks/job_task'
require 'tootsie/tasks/notify_task'
require 'tootsie/output'
require 'tootsie/web_service'
require 'tootsie/processors/video_processor'
require 'tootsie/processors/image_processor'
require 'tootsie/queues/sqs_queue'
require 'tootsie/queues/file_system_queue'
require 'tootsie/s3'
