require "rake"
require "rake/tasklib"

module ChainGang
  module Rake
    class DaemonTask < ::Rake::TaskLib
      # The name of the daemon being created
      attr_accessor :name

      # The path to the daemon's worker
      attr_accessor :worker

      # Defines a new task, using the path to the worker.
      def initialize(worker)
        @worker = worker
        @name = File.basename(@worker).gsub(/\.rb$/, "").downcase
        yield self if block_given?
        build_tasks
      end

    private
      def build_tasks # :nodoc:
        if worker == nil
          raise ArgumentError, "Worker must be set."
        end
        desc "Start the #{name} daemon"
        task :start do
          exec("ruby -e \"require '#{worker}'; ChainGang.work\"")
        end
        desc "Stop the #{name} daemon"
        task :stop do
          exec("ruby -e \"require '#{worker}'; ChainGang.stop_daemons\"")
        end
        desc "Restart the #{name} daemon"
        task :restart do
          exec("ruby -e \"require '#{worker}'; ChainGang.restart_daemons\"")
        end
        self
      end
    end
  end
end
