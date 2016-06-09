#!/bin/sh
api_key=datadoc_api
app_key=datadog_app

name="deployment_name or replica controller name"
namespace="namespace only needs when using replioca controller"

to_time=$(date +%s)
# 5 mins
from_time=$(( to_time - 300 ))

metric="name"

queue=$(curl -s -G \
    "https://app.datadoghq.com/api/v1/query" \
    -d "api_key=${api_key}" \
    -d "application_key=${app_key}" \
    -d "from=${from_time}" \
    -d "to=${to_time}" \
    -d "query=avg:$metric{*}by{host}" \
    | jq -r '.series[].pointlist[-1][1]')

echo "Current value of metric: $queue"

local replica=0
case 1 in
  $(($queue<= 100))) replica=1;;
  $(($queue> 100 && $queue<= 1000))) replica=1;;
  $(($queue> 1000 && $queue<= 10000))) replica=2;;
  $(($queue> 10000 && $queue<= 100000))) replica=4;;
  $(($queue> 100000 ))) replica=8;;
esac

/usr/local/bin/kubectl scale --replicas=$replica deployment/$name
#echo kubectl scale --replicas=$replica rc $rc --namespace=$namespace


