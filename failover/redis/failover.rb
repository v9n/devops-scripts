#!/usr/bin/env ruby

require 'open3'

module Failover
  class Redis
    attr_reader :nodes
    attr_reader :sleep_interval
    attr_reader :config, :inspector

    def initialize
      File.open("/etc/default/redis-failover").each_line do |line|
        kv = line.split("=").map(&:strip)
        case kv[0]
        when 'FILES'
          @config = Config.new kv[1]
        when 'REDIS_NODES'
          @nodes = kv[1].split(" ").map(&:strip).last.split(",").map(&:strip)
        when 'SLEEP_INTERVAL'
          @sleep_interval = kv[1].to_i
        end
      end
      @inspector = Inspector.new @nodes
      puts @nodes
    end

    def run
      while true do
        failover

        master = inspector.find_master
        puts "master is #{master}"
        current_redis = config.find_redis_ip
        puts "current redis in config is #{current_redis}"

        if master != current_redis
          config.update_redis_ip current_redis, master
        end

        puts "Sleep #{sleep_interval} seconds\n\n\n"
        sleep sleep_interval
      end
    end

    def failover
      @nodes.each do |node|
        if !inspector.up? node
          puts "Inspect #{node}: down"
          # When master is down, we promote the other one
          puts "#{node} is a master. kick in failover"
          random_slave = @nodes.select { |ip| node != ip }.first
          if inspector.master? random_slave
            puts "#{random_slave} is set to master already"
          else
            puts "#{random_slave} will be set to master"
            inspector.promote! random_slave
          end
        else
          puts "Inspect #{node}: up"
          master = inspector.find_master
          if inspector.master?(node) && master != node
            puts "Set #{node} to slave of #{master}"
            inspector.slave! node, master
          end
        end
      end
    end
  end

  class Config
    attr_reader :config_file
    def initialize(path)
      @config_file = path
    end

    def find_redis_ip
      content = File.read(config_file)
      parts   = content.split("WS4REDIS_CONNECTION = {")[1]
      ip = nil
      parts.split("\n").each do |line|
        tokens = line.split(':').map(&:strip)
        if tokens[0] == "'host'"
          ip = tokens[1].gsub(/[',]/, "").strip
          break
        end
      end
      ip
    end

    def update_redis_ip(from, ip)
      puts "Will update redis ip from #{from} to #{ip}"
      content = File.read(config_file)
      content = content.gsub("'host': '#{from}',","'host': '#{ip}',")
      File.write(config_file, content)
    end
  end

  class Inspector
    attr_reader :nodes
    def initialize(nodes)
      @nodes = nodes
    end

    def find_master
      @nodes.select { |node| master?(node) }.first
    end

    # Check if Redis is up on this server
    def up?(ip)
      o, e, s = Open3.capture3("redis-cli -h #{ip} INFO")
      s.success?
    end

    def master?(ip)
      o, e, s = Open3.capture3("redis-cli -h #{ip} INFO")
      o.include?("role:master")
    end

    def promote!(ip)
      o, e, s = Open3.capture3("redis-cli -h #{ip} SLAVEOF NO ONE")
      s.success?
    end

    def slave!(ip, master)
      o, e, s = Open3.capture3("redis-cli -h #{ip} SLAVEOF #{master} 6379")
      s.success?
    end
  end
end


f = Failover::Redis.new
f.run
