# curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/env.sh | bash

# sypctl upgrade
# sypctl linux:date check
# tree /usr/local/src/syp-etl

# ls /usr/local/src/syp-etl/*.todo
# sypctl toolkit date interval $(cat /usr/local/src/syp-etl/running.timestamp)
# echo \"Time.now.strftime('%y-%m-%d %H:%M:%S')\" && sypctl linux:date view
# echo \"#{config['inner_ip']} $(date +'%z %m/%d/%y %H:%M:%S')\"
# time ssh 192.168.30.110 \"date +'%z %m/%d/%y %H:%M:%S'\"

tail -n 50 /var/log/sypctl-linux-date-checker.log

# echo '0 2 * * 0 /usr/hdp/share/hst/bin/hst-scheduled-capture.sh' > /etc/root-crontab.conf
# echo '' >> /etc/root-crontab.conf
# echo '0 */2 * * * sypctl memory:free >> /var/log/sypctl-memory-free.log 2>&1' >> /etc/root-crontab.conf
# echo '*/5 * * * * sypctl linux:date check >> /var/log/sypctl-linux-date-checker.log 2>&1' >> /etc/root-crontab.conf
# crontab /etc/root-crontab.conf