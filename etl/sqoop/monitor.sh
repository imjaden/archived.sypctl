#!/usr/bin/env bash
#
# crontab job:
# */5 * * * * bash /usr/local/src/syp-etl/monitor.sh
#
test -f ~/.bash_proflie && source ~/.bash_profile

sypctl etl:status

if [[ $? -eq 0 ]]; then
  echo "$(date) running..." >> /usr/local/src/syp-etl/running.log 2>&1
else
  echo "$(date) starting..." >> /usr/local/src/syp-etl/restart.log 2>&1
  sypctl etl:import /usr/local/src/syp-etl/databases.json
fi
