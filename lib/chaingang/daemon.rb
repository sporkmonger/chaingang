module ChainGang
  # This class logically represents the running daemon process after fork.
  # It needs to be given a reference to a worker object that responds to the
  # :call message.
  class Daemon
    def initialize(options={})
      @alive = true
      @options = {:threads => 1, :signals => {}}.merge(options)
      @worker = @options[:worker]
      if @worker == nil
        raise ArgumentError,
          "Expected :worker option to be specified."
      elsif !@worker.respond_to?(:call)
        raise TypeError,
          "Expected #{@worker.class} to respond to :call message."
      end
      if !@options[:signals].respond_to?(:to_hash)
        raise TypeError,
          "Cannot convert #{options[:signals].class} to Hash."
      end
      if !@options[:threads].kind_of?(Integer) || @options[:threads] <= 0
        raise ArgumentError,
          "Expected :threads option to be an Integer greater than 0."
      end
      @threads = []
      @signals = @options[:signals].to_hash.merge({
        "TERM" => lambda do
          @alive = false
        end,
        "HUP" => "IGNORE"
      })
    end

    def worker
      return @worker
    end

    def alive?
      return @alive
    end

    def config
      @config ||= {
        :pidfile => (
          @worker.kind_of?(Proc) ?
            "chaingang.pid" :
            @worker.class.name.downcase.gsub(/^.*::/, "") + ".pid"
        )
      }.merge(@worker.respond_to?(:config) ? @worker.config : {})
    end

    def pidfile
      if !config[:pidfile].respond_to?(:to_str)
        raise TypeError,
          "Could not convert #{config[:pidfile].class} to String."
      end
      pidfile = config[:pidfile].to_str
      if File.exists?("tmp/pids")
        pidfile = File.join("tmp/pids", pidfile)
      elsif File.exists?("tmp")
        pidfile = File.join("tmp", pidfile)
      elsif File.exists?("log")
        pidfile = File.join("log", pidfile)
      end
      return pidfile
    end

    def setup
      @worker.setup if @worker.respond_to?(:setup)
    end

    def teardown
      @worker.teardown if @worker.respond_to?(:teardown)
    end

    def options
      return @options
    end

    def threads
      return @threads
    end

    def run
      @signals.each do |(signal, action)|
        if action.kind_of?(Proc)
          Signal.trap(signal, &action)
        elsif action.kind_of?(String)
          Signal.trap(signal, action)
        else
          raise TypeError, "Expected #{action.class} to be String or Proc."
        end
      end
      setup
      options[:threads].times do
        threads << Thread.new do
          Thread.pass
          while(alive?)
            worker.call
            Thread.pass
          end
        end
      end
      threads.each { |thread| thread.join }
      teardown
    end
  end
end
