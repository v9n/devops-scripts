#!/bin/bash

EMAIL="$1"
PASS="$2"
API="$3"

check_ids=`curl -s -u "$EMAIL:$PASS"  --header "Account-Email: $EMAIL" --header "App-Key: $API" https://api.pingdom.com/api/2.0/checks  | jq -r '.["checks"][] | "\(.id) \(.hostname)"'`

while read -r line; do
  line=`echo $line | sed ':a;N;$!ba;s/\n/ /g'`
  id=`echo $line | awk '{print $1}'`
  name=`echo $line | awk '{print $2}'`

  response_time=`curl -s -u "$EMAIL:$PASS" --header "App-Key: $API" "https://api.pingdom.com/api/2.0/results/$id?limit=1" | jq -r '.["results"][]["responsetime"]'`
  echo "Pingdom Check $name OK | $name=$response_time"
done <<< "$check_ids"

