#!/usr/bin/env ruby
require 'json'
require 'time'
require 'open3'
require 'logger'

# Cleanup old snapshot
module Aws
  module Ebs
    class Shell
      def self.log message
        @@logger ||= Logger.new(STDOUT)
        @@logger.info message
      end

      def self.run(*cmd, **opts)
        log "Run #{cmd.join("; ")}"
        stdin, stdout, stderr, wait_thr = Open3.popen3(*cmd , **opts)
        [stdout.read, stderr.read]
      end
    end

    class SnapshotCleaner
      attr_reader :opts

      def initialize(aws)
        @opts = {:aws => aws }
      end

      def find_due_snapshot(age_threshold)
        snapshots = get_snapshot
        now = Time.now
        snapshots["Snapshots"].select do |snap|
          created_at = Time.parse snap["StartTime"]
          snap_age =  (now - created_at).to_i / (24 * 60 * 60)
          snap_age > age_threshold &&
            !snap['Tags'].nil? &&
            snap["Description"].include?("ec2ab_vol") &&
            snap["Tags"].any? { |t| t["Value"] == "ec2-automate-backup" }
        end
      end

      def clean(age)
        puts "We will delete snapshot that is older than #{age} days"
        age = age.to_i
        find_due_snapshot(age).each do |snap|
          puts snap["Description"]
          puts snap["StartTime"]
          puts snap["SnapshotId"]

          delete_snapshot snap["SnapshotId"]
        end
      end

      private
      def get_snapshot
        raw_response, err = Shell.run "#{opts[:aws]} ec2 describe-snapshots"
        JSON.parse raw_response
      end

      def delete_snapshot(id)
        Shell.run "#{opts[:aws]} ec2 delete-snapshot --snapshot-id #{id}"
      end

    end
  end
end

unless $PROGRAM_NAME.include? "_test"
  c = Aws::Ebs::SnapshotCleaner::new(ARGV[0] || 'aws')
  c.clean ARGV[1] || 45
end
