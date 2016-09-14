#!/usr/bin/env ruby
require 'json'
require 'time'
require 'open3'
require 'logger'
require 'rethinkdb'

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

  class RethinkDB
    include ::RethinkDB::Shortcuts
    DB_NAME = 'haplog'

    attr_reader :conn
    attr_reader  :logger

    def initialize
      @logger = Logger.new(STDOUT)
      @conn = r.connect
      if !r.db_list.run(conn).include? DB_NAME
        r.db_create(DB_NAME).run conn
        r.db(DB_NAME).table_create('log').run conn
      end
    end

    def write(record)
      logger.debug record
      r.db(DB_NAME).table('log').insert(record).run(conn)
    end

  end
end

unless $PROGRAM_NAME.include? "_test"
  w = Importer::RethinkDB.new
  r = Importer::Haproxy.new(ARGV[0] || 'ip.log')
  importer = Importer::Importer.new(r, w)
  importer.run
end
