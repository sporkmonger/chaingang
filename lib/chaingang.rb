# ++
# ChainGang, Copyright (c) 2009 Bob Aman
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# --

require "chaingang/version"
require "chaingang/daemon"

module ChainGang
  def self.prepared_daemon
    return @prepared_daemon
  end

  def self.prepare(worker_or_daemon=nil, &block)
    if worker_or_daemon != nil && block != nil
      raise ArgumentError,
        "Either supply a worker or a block, but not both."
    elsif block != nil
      worker_or_daemon = block
    end
    daemon = (worker_or_daemon.kind_of?(ChainGang::Daemon) ?
      worker_or_daemon : ChainGang::Daemon.new(:worker => worker_or_daemon))
    return (@prepared_daemon = daemon)
  end

  def self.work(worker_or_daemon=nil, &block)
    if !worker_or_daemon && !block && self.prepared_daemon
      daemon = self.prepared_daemon
    else
      daemon = self.prepare(worker_or_daemon, &block)
    end
    pid = self.fork_daemon(daemon)
    self.write_pidfile(pid, daemon)
    return pid
  end

  def self.write_pidfile(pid, daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    File.open(daemon.pidfile, "a") { |file| file.write(pid.to_s + "\n") }
  end

  def self.read_pidfile(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    if File.exist?(daemon.pidfile)
      return File.open(daemon.pidfile, "r") do |file|
        file.read.split("\n").map { |pid| pid.to_i }
      end
    else
      return []
    end
  end

  def self.clear_pidfile(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    if File.exist?(daemon.pidfile)
      return File.delete(daemon.pidfile)
    end
  end

  def self.fork_daemon(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    return fork { daemon.run }
  end

  def self.stop_daemons(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    pids = self.read_pidfile(daemon)
    pids.each do |pid|
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        # Ignore issues with missing processes
      end
    end
    self.clear_pidfile(daemon)
    return pids
  end

  def self.restart_daemons(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    pids = self.stop_daemons(daemon)
    return pids.inject([]) { |accu, _| accu << self.fork_daemon(daemon) }
  end

  def self.check_daemons(daemon=nil)
    daemon = self.prepared_daemon if daemon == nil
    if !daemon.kind_of?(ChainGang::Daemon)
      raise TypeError, "Expected ChainGang::Daemon, got #{daemon.class}."
    end
    pids = self.read_pidfile(daemon)
    return pids.inject({}) do |accu, pid|
      begin
        Process.getpriority(Process::PRIO_PROCESS, pid)
        status = true
      rescue Errno::ESRCH
        status = false
      end
      accu[pid] = status
      accu
    end
  end
end
