#!/usr/bin/env ruby
require 'json'
require 'time'
require 'open3'
require 'logger'
require 'rethinkdb'
require 'thread'

# Cleanup old snapshot
module Importer

  class Importer
    attr_reader :source, :destination

    def initialize(source, destination)
      @source = source
      @destination = destination
    end

    # Example record
    def process(record)
      record = record.split ' '
      {
        log_time: record[0],
        node: record[1],
        process: record[2],
        ip: record[3].split(':').first,
        hit_time: record[4],
        be: record[5],
        backend_server: record[6],
        status: record[8],
        path: record[-2],
        method: record[-3],
        agent: record[15],
      }
    end

    def run
      source.read do |record|
        destination.write(process(record))
      end
    end
  end

  class Haproxy
    attr :source

    def initialize(source)
      @source = source
    end

    def read
      IO.foreach(source) do |line|
        yield line
      end
    end
  end

  class Stdout
    attr_reader :logger

    def initialize
      @logger = Logger.new(STDOUT)
    end

    def write(record)
      puts record[:ip] if validate_ip(record[:ip])
    end

    private
    def validate_ip(ip)
      block = /\d{,2}|1\d{2}|2[0-4]\d|25[0-5]/
      re = /\A#{block}\.#{block}\.#{block}\.#{block}\z/
      re =~ ip
    end

  end


  class RethinkDB
    include ::RethinkDB::Shortcuts
    DB_NAME = 'haplog'

    attr_reader :conn
    attr_reader :logger
    attr_reader :workers, :queue

    def initialize
      @logger = Logger.new(STDOUT)
      @conn = r.connect
      if !r.db_list.run(conn).include? DB_NAME
        r.db_create(DB_NAME).run conn
        r.db(DB_NAME).table_create('log').run conn
      end
      Thread.new { start_worker_pool }
    end

    def write(record)
      raise "Please init queue" unless queue
      queue.push record
    end

    private
    def start_worker_pool(count=20)
      @queue = Queue.new
      @workers ||= (0...count).map do
        Thread.new do
          begin
              while record = queue.pop
                logger.debug record
                r.db(DB_NAME).table('log').insert(record, durability: 'soft').run(conn)
              end
          rescue ThreadError => e
            puts e
            puts "Fail to creeate thread"
          end
        end
      end
      workers.map(&:join)
    end
  end
end

unless $PROGRAM_NAME.include? "_test"
  if ARGV[1]
    w = Importer::Stdout.new
  else
    w = Importer::RethinkDB.new
  end
  r = Importer::Haproxy.new(ARGV[0] || 'ip.log')
  importer = Importer::Importer.new(r, w)
  importer.run
end
