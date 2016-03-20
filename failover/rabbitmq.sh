#!/bin/bash

# Ref: http://redsymbol.net/articles/unofficial-barbmq-strict-mode/
set -euo pipefail
#IFS=$'\n\t'

source /etc/default/rbmq-failover
# Those two variable should be in /etc/default/rbmq-failover
# SLEEP_INTERVAL=10
# FILES=(/etc/hosts)
# RABBITMQ_NODES=(127.0.0.1 127.0.0.1)

if [ -z "$FILES" ]; then
  echo "No file to do"
  sleep $SLEEP_INTERVAL
  exit 1
fi

if [ 1 -eq ${#RABBITMQ_NODES[@]} ]; then
  echo "Only one node."
  sleep $SLEEP_INTERVAL
  exit 1
fi

dlog () {
  if [ $DEBUG -eq 1 ]; then
    echo "$@"
  fi
}
# return 0 when rabbitmq is down
# we rely on http management plugin
is_down () {
  local address="$1"
  dlog "Check $address"
  if curl -sv http://$address:15672/ 2>&1 | grep '200 OK'; then
    return 1
  else
    return 0
  fi
}

# failover file bad-ip
# failover pickup first good-ip in list, and replace bad-ip with it in file
failover () {
  # replace name in hostfile
  # sed ......
  local file_to_replace="$1"
  local failed_ip="$2"

  for node in ${RABBITMQ_NODES[@]}; do
    if [ ! "$failed_ip" = "$node" ]; then
      dlog sed -i "s/@$failed_ip:5672/@$node:5672/g" "$file_to_replace"
      sed -i "s/@$failed_ip:5672/@$node:5672/g" "$file_to_replace"
    fi
  done
  return 0
}

# run after failover kickin
post_failover () {
  # Notify hipchat/slac for example
  return 0
}

run () {
  local address
  while true; do
    for file in ${FILES[@]}; do
      address=`cat $file | grep rabbitmq | awk -F @ '{print $2}' | awk -F ':' '{print $1}'`
      if is_down $address; then
        failover $file $address
        post_failover
      else
        dlog "$address up"
      fi
    done
    dlog sleep $SLEEP_INTERVAL
    sleep $SLEEP_INTERVAL
  done
}

run

