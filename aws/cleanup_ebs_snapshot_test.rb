require 'minitest/autorun'
require 'mocha/mini_test'
require 'timecop'
require './cleanup_ebs_snapshot'

module Aws
  module Ebs
    class TestShell < Minitest::Test
      def test_run
        `mkdir /tmp/test1234; touch /tmp/test1234/foo;touch /tmp/test1234/bar`
        out, _ = Aws::Ebs::Shell.run "ls /tmp/test1234/"
        assert_equal true, out.include?("foo")
        `rm -rf /tmp/test1234`
      end
    end

    class TestCleanup < Minitest::Test

      FAKE_SNAPSHOT = {
        "Description" => "fake",
        "StartTime" => "fake",
        "SnapshotId" => "snap-foo"
      }

      SNAPSHOT_RESPONSE = 
        <<-EOL
        { "Snapshots":
            [
                {
                    "Description": "ec2ab_vol-34cd28e4_1468223403", 
                    "Encrypted": false,
                    "VolumeId": "vol-bar",
                    "State": "completed",
                    "VolumeSize": 100,
                    "Progress": "100%",
                    "StartTime": "2015-05-02T09:11:23.000Z",
                    "SnapshotId": "snap-bar",
                    "OwnerId": "bar"
                },

                {
                    "Description": "ec2ab_vol-34cd28e4_1468223403", 
                    "Tags": [
                        {
                            "Value": "ec2-automate-backup", 
                            "Key": "CreatedBy"
                        }, 
                        {
                            "Value": "true",
                            "Key": "PurgeAllow"
                        }, 
                        {
                            "Value": "1470901803", 
                            "Key": "PurgeAfterFE"
                        }
                    ],
                    "Encrypted": false,
                    "VolumeId": "vol-foo",
                    "State": "completed",
                    "VolumeSize": 100,
                    "Progress": "100%",
                    "StartTime": "2015-05-02T09:11:23.000Z",
                    "SnapshotId": "snap-foo",
                    "OwnerId": "foo"
                }
            ]
        }
        EOL
      

      def test_find_due_snapshot
         mock = MiniTest::Mock.new
         mock.expect(:call, SNAPSHOT_RESPONSE, ["aws ec2 describe-snapshots"])
         Aws::Ebs::Shell.stub(:run, mock, ["aws ec2 describe-snapshots"]) do
          cleaner = Aws::Ebs::SnapshotCleaner.new 'aws'
          snaps = cleaner.find_due_snapshot(45)
          assert_equal "snap-foo", snaps.first["SnapshotId"]
         end
         mock.verify
      end

      def test_find_due_snapshot_when_age_is_too_young
         mock = MiniTest::Mock.new
         mock.expect(:call, SNAPSHOT_RESPONSE, ["aws ec2 describe-snapshots"])
         Aws::Ebs::Shell.stub(:run, mock, ["aws ec2 describe-snapshots"]) do
          cleaner = Aws::Ebs::SnapshotCleaner.new 'aws'
          Timecop.freeze(Time.local(2015, 5, 30)) do
            snaps = cleaner.find_due_snapshot(45)
            assert_equal [], snaps
          end
         end
         mock.verify
      end

      def test_clean
        mock = MiniTest::Mock.new
         mock.expect(:call, "", ["aws ec2 delete-snapshot --snapshot-id snap-foo"])
         Aws::Ebs::Shell.stub(:run, mock, ["aws ec2 delete-snapshot --snapshot-id snap-foo"]) do
          cleaner = Aws::Ebs::SnapshotCleaner.new 'aws'
          cleaner.expects(:find_due_snapshot).with(10).returns([FAKE_SNAPSHOT])
          cleaner.clean(10)
         end
         mock.verify
      end

      def test_passing_attribute
        cleaner = Aws::Ebs::SnapshotCleaner.new 'aws --profile test'

        assert cleaner.opts[:aws] == 'aws --profile test'
      end

    end
  end
end
