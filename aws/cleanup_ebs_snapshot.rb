#!/usr/bin/env ruby
require 'json'
require 'time'
require 'open3'
require 'logger'
require 'optparse'

# Cleanup old snapshot
module Aws
  def self.log message
    @@logger ||= Logger.new(STDOUT)
    @@logger.debug message
  end

  module Ebs
    class Shell
      def self.run(*cmd, **opts)
        Aws.log "Run #{cmd.join("; ")}"
        stdin, stdout, stderr, wait_thr = Open3.popen3(*cmd , **opts)
        [stdout.read, stderr.read]
      end
    end

    class SnapshotCleaner
      attr_reader :opts
      def initialize(opts)
        @opts = opts
      end

      def find_due_snapshot
        snapshots = get_snapshot
        now = Time.now
        snapshots["Snapshots"].select do |snap|
          created_at = Time.parse snap["StartTime"]
          snap_age =  (now - created_at).to_i / (24 * 60 * 60)
          snap_age > opts[:age] &&
            !snap['Tags'].nil? &&
            snap["Tags"].any? { |t| opts[:tag].any? { t["Value"].include? _1 } }
            #snap["Description"].include?("ec2ab_vol") &&
            #snap["Tags"].any? { |t| t["Value"] == "ec2-automate-backup" }
        end
      end

      def clean!
        Aws.log "We will delete snapshot with this filter #{opts}"
        find_due_snapshot.each do |snap|
          Aws.log snap["Description"]
          Aws.log snap["StartTime"]
          Aws.log snap["SnapshotId"]

          delete_snapshot snap["SnapshotId"]
        end
      end

      private
      def get_snapshot
        raw_response, err = Shell.run "#{opts[:aws]} ec2 describe-snapshots"
        JSON.parse raw_response
      end

      def delete_snapshot(id)
        Aws.log "Delete #{id}"
        Shell.run "#{opts[:aws]} ec2 delete-snapshot --snapshot-id #{id}"
      end

    end
  end
end

unless $PROGRAM_NAME.include? "_test"
  options = {
    # aws is path or any option to our aws cli
    aws: 'aws',
    age: 7
  }
  OptionParser.new do |opts|
    opts.banner = "Usage: cleanup_ebs_snapshot.rb --age in-hour --tag anything-has-this-tag"

    opts.on("-aAGE","--age=AGE", "Age of snapsot") do |v|
      options[:age] = v.to_i
    end

    opts.on("--tag=TAG", "List if tag") do |v|
      options[:tag] = v.strip.split(",")
    end

    opts.on("--aws=AWS", "aws path") do |v|
      options[:aws] = v
    end
  end.parse!

  c = Aws::Ebs::SnapshotCleaner::new(options)
  c.clean!
end
