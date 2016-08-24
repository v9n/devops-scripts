#!/bin/bash

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
  echo "Restore $1"
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
