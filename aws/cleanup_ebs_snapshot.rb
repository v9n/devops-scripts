#!/usr/bin/env ruby
require 'json'
require 'time'

# Cleanup old snapshot
module Aws
  module Ebs
    class SnapshotCleaner
      attr_reader :opts

      def initialize(aws)
        @opts = {:aws => aws }
      end

      def find_due_snapshot(age_threshold)
        snapshots = get_snapshot
        now = Time.now
        snapshots["Snapshots"].select {|snap| !snap['Tags'].nil? && snap["Tags"].any? { |t| t["Value"] == "ec2-automate-backup"  }}.select do |snap|
          created_at = Time.parse snap["StartTime"]
          snap_age =  (now - created_at).to_i / (24 * 60 * 60)
          snap_age > age_threshold
        end
      end

      def clean(age)
        puts "We will delete snapshot that is older than #{age} days"
        exit

        find_due_snapshot(age).each do |snap|
          puts snap["StartTime"]
          puts snap["SnapshotId"]
          delete_snapshot snap["SnapshotId"]
        end
      end

      private
      def get_snapshot
        raw_response = `#{opts[:aws]} ec2 describe-snapshots`
        JSON.parse raw_response
      end

      def delete_snapshot(id)
        puts "#{opts[:aws]} ec2 delete-snapshot --snapshot-id #{id}"
        `#{opts[:aws]} ec2 delete-snapshot --snapshot-id #{id}`
      end

    end
  end
end

# 45 days
c = Aws::Ebs::SnapshotCleaner::new(ARGV[0] || 'aws')
c.clean ARGV[1] || 45
