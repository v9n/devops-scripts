#!/bin/bash

set -eu
set -o pipefail

HOSTNAME=`hostname`
DATA_DIR="/ebs/data"
S3BUCKET="###"

# https://docs.datastax.com/en/cassandra/3.x/cassandra/operations/opsSnapshotRestoreNewCluster.html?hl=restoring,snapshot,new,cluste
restore_token () {
  echo "Restore token and reset node"
  # remove system data
}

# Restore a keyspace
restore_keyspace () {
  KEYSPACE="$1"
  echo -e "\n==============================\nStart restore $KEYSPACE"
  table_list=()
  for node in `aws s3 ls s3://$S3BUCKET | awk '{print $2}'`; do
    echo "  Inspect Node: $node"

    for table in `aws s3 ls s3://$S3BUCKET/$node$KEYSPACE/ | awk '{print $2}'`; do
      table_list+=("$table")

      if [ ! -d $DATA_DIR/$KEYSPACE/$table ]; then
        mkdir $DATA_DIR/$KEYSPACE/$table || true
      fi

      echo "    Table: $table"
      latest_snapshot=`aws s3 ls s3://$S3BUCKET/$node$KEYSPACE/$table | tail -n1 | awk '{print $2}'`
      echo "    Latest: $latest_snapshot"

      echo "      -> list table aws s3 ls s3://$S3BUCKET/$node$KEYSPACE/$table$latest_snapshot"
      for sstable in `aws s3 ls s3://$S3BUCKET/$node$KEYSPACE/$table$latest_snapshot | grep 'ma-' | awk '{print $4}'`; do
        echo "      -> sstable: $sstable"
        local node_number=`echo $node | sed "s/[^0-9]//g"`
        sstable_new_name=`echo $sstable | sed "s/ma-/ma-$node_number/g"`
        echo "      ->" Copy sstable: aws s3 cp s3://$S3BUCKET/$node$KEYSPACE/$table$latest_snapshot$sstable $DATA_DIR/$KEYSPACE/$table$sstable_new_name
        # Temp disable for test
        #aws s3 cp s3://$S3BUCKET/$node$KEYSPACE/$table$latest_snapshot$sstable $DATA_DIR/$KEYSPACE/$table$sstable_new_name
      done
    done

    echo -e "\n\n"
  done

  for t in "${table_list[@]}"; do
    t=`echo $t | sed  "s/\// /g"`
    echo "  -> Table: $t"
    local ip=`ip addr show eth0 | grep -Po 'inet \K[\d.]+'`
    echo "  -> " sstableloader -d $ip $DATA_DIR/$KEYSPACE/$t
    sstableloader -d $ip $DATA_DIR/$KEYSPACE/$t
  done
}

restore_data () {
  for keyspace in `cqlsh -e "describe keyspaces"`; do
    case $keyspace in
      system|system_auth|system_distributed|system_schema|system_traces)
        continue;;
      *)
        restore_keyspace "$keyspace"
    esac
  done
}

main () {
  restore_token
  restore_data $1
}

main $1
