# disable Sinatra's logger
disable :logging

# enable combined log format
use Clogger, format: :Combined, logger: $stdout, reentrant: true
