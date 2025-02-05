$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

$TESTING = true

require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'test/unit'
require 'resque-multi-job-forks'
require 'timeout'

# setup redis & resque.
$redis = Redis.new(:db => 1)
Resque.redis = $redis

# adds simple STDOUT logging to test workers.
# set `VERBOSE=true` when running the tests to view resques log output.
module Resque
  class Worker
    attr_accessor :start_lag

    def log_with_severity(severity, msg)
      if ENV['VERBOSE']
        s = severity.to_s[0].upcase
        $stderr.print "*** [#{Time.now}] [#{Process.pid}] #{self} #{s}: #{msg}\n"
      end
    end

    def report_failed_job(job, exception)
      $SEQ_WRITER.print "failed_job_#{exception.class.name.downcase.gsub('::', '_')}\n"
    end

    def fork_hijacked?
      if @release_fork_limit
        if start_lag
          sleep start_lag
        end
      end
      @release_fork_limit
    end
  end
end

# test job, tracks sequence.
class SequenceJob
  @queue = :jobs
  def self.perform(i)
    sleep(2)
    $SEQ_WRITER.print "work_#{i}\n"
  end
end

class QuickSequenceJob
  @queue = :jobs
  def self.perform(i)
    $SEQ_WRITER.print "work_#{i}\n"
  end
end


# test hooks, tracks sequence.
Resque.after_fork do
  $SEQ_WRITER.print "after_fork\n"
end

Resque.before_fork do
  $SEQ_WRITER.print "before_fork\n"
end

Resque.before_child_exit do |worker|
  $SEQ_WRITER.print "before_child_exit_#{worker.jobs_processed}\n"
end
