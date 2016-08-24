#!/bin/bash -l

HOSTNAME=`hostname`
DATA_DIR="/ebs/data"
S3BUCKET="####"

ring() {
  nodetool ring | grep `ip addr show | grep 'scope global' | awk '{print $2}' | awk -F'/' '{print $1}'` | awk '{print $NF ","}' | xargs > /tmp/ring
  aws s3 cp /tmp/ring s3://$S3BUCKET/$HOSTNAME/ring
  rm -rf /tmp/ring
}

make_snapshot () {
  nodetool snapshot
}

sync_snapshot () {
  for keyspace in `cqlsh -e "describe keyspaces"`; do
    for snapshot_dir in `ls $DATA_DIR/$keyspace/*/snapshots/*/ | grep 'ebs' | awk -F':'  '{print $1}'`; do
      echo "$keyspace -> $snapshot_dir. Sync to s3 now..."
      SNAPSHOT=`basename $snapshot_dir`
      echo "S= $SNAPSHOT"

      TABLE=`basename $(dirname $(dirname $snapshot_dir))`
      TABLE=`echo $TABLE | awk -F'-' '{print $1}'`

      echo table name $TABLE
      echo aws s3 sync "$snapshot_dir" s3://$S3BUCKET/$HOSTNAME/$keyspace/$TABLE/$SNAPSHOT
      aws s3 sync "$snapshot_dir" s3://$S3BUCKET/$HOSTNAME/$keyspace/$TABLE/$SNAPSHOT
    done
    echo -e "\n\n"
  done
}

main () {
  ring
  #make_snapshot
  sync_snapshot
}

main
