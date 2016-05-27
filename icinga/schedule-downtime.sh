#!/bin/bash

###############
# Icinga config
ICINGA_USER=icinga
ICINGA_PASS=icinga
ICINGA_HOST=10.1.1.1
# Stop edit
#=============

COMMAND="$1"
HOSTS="$2"
DOWNTIME="$3"

if [ -z "$HOSTS" ]; then
  echo 'missing hostname'
  exit 1
fi

if [ -z "$DOWNTIME" ]; then
  DOWNTIME=10
fi

START_TIME=`date "+%m-%d-%Y %H:%M:%S"`

now=`date`
echo now is $now
echo date "+%m-%d-%Y %H:%M:%S" --date="$now + $DOWNTIME minutes"
END_TIME=`date "+%m-%d-%Y %H:%M:%S" --date="$now + $DOWNTIME minutes"`

echo $START_TIME
echo $END_TIME

for HOST in $(echo $HOSTS | sed "s/,/ /g"); do
  case "$COMMAND" in
    down)
      curl "http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi" \
             -u "$ICINGA_USER:$ICINGA_PASS" \
             -H "Referer: http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi?cmd_typ=29&host=$HOST" \
             -H 'Content-Type: application/x-www-form-urlencoded' \
             --data "cmd_typ=29&cmd_mod=2&host=$HOST&btnSubmit=Commit"
      curl "http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi" \
             -u "$ICINGA_USER:$ICINGA_PASS" \
             -H "Referer: http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi?cmd_typ=86&host=$HOST" \
             -H 'Content-Type: application/x-www-form-urlencoded' \
             --data "cmd_typ=86&cmd_mod=2&host=$HOST&com_author=$ICINGA_USER&com_data=AutoScheduleDowntime&trigger=0&start_time=$START_TIME&end_time=$END_TIME&fixed=1&hours=0&minutes=$DOWNTIME&childoptions=0&btnSubmit=Commit"
      ;;
    up)
      curl "http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi" \
             -u "$ICINGA_USER:$ICINGA_PASS" \
             -H "Referer: http://$ICINGA_HOST/icinga/cgi-bin/cmd.cgi?cmd_typ=28&host=$HOST" \
             -H 'Content-Type: application/x-www-form-urlencoded' \
             --data "cmd_typ=28&cmd_mod=2&host=$HOST&btnSubmit=Commit"
      ;;
  esac

done
