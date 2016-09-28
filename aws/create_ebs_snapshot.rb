#!/usr/bin/env ruby
require 'json'
require 'time'
require 'open3'
require 'logger'

# Cleanup old volume
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

    class SnapshotCreator
      attr_reader :opts

      def initialize(aws)
        @opts = {:aws => aws }
      end

      def find_tagged_volumes(age_threshold)
        volumes = get_volumes
        now = Time.now
        volumes["Volumes"].select do |volume|
          volume['Tags'] && volume["Tags"].any? { |t| t["Key"] == "auto-backup" }
        end
      end

      def create(age)
        Aws.log "We will create volume that has `auto-backup` tag"
        age = age.to_i
        find_tagged_volumes(age).each do |volume|
          Aws.log volume["VolumeId"]

          create_snapshot volume["VolumeId"]
        end
      end

      private
      def get_volumes
        raw_response, err = Shell.run "#{opts[:aws]} ec2 describe-volumes"
        JSON.parse raw_response
      end

      def create_snapshot(id)
        cmd = "echo #{opts[:aws]} ec2 delete-volume --volume-id #{id}"
        puts cmd
        #Shell.run "echo #{opts[:aws]} ec2 delete-volume --volume-id #{id}"
      end

    end
  end
end

unless $PROGRAM_NAME.include? "_test"
  c = Aws::Ebs::SnapshotCreator::new(ARGV[0] || 'aws')
  c.create ARGV[1] || 45
end
