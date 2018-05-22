
# -----------------------------------------------
# 生意+ 项目进程，开机启动
# CentOS: /etc/rc.d/rc.local
# Ubuntu: /etc/rc.local
# -----------------------------------------------
# >>>>>>>>>>>>>>>>>>>> 脚本开始 >>>>>>>>>>>>>>>>>>>
test -d /opt/scripts/syp-saas-scripts && {
  cd /opt/scripts/syp-saas-scripts
  sudo -u root bash sypctl.sh monitor
  sudo -u root bash sypctl.sh firewalld:stop
  sudo -u root crontab linux/config/syp@crontab.conf
}

test -d /root/www/syp-saas-server && {
  cd /root/www/syp-saas-server 
  sudo -u root bash tool.sh start
  sudo -u root bash tool.sh crontab:update
}

command -v mysqld > /dev/null 2>&1 && {
  systemctl start mysqld
}

command -v vncserver > /dev/null 2>&1 && {
  systemctl daemon-reload
  vncserver -list | grep '^:' | awk '{ print $1 }' | xargs vncserver -kill
  vncserver -geometry 1024x768 -depth 24
}

command -v nginx > /dev/null 2>&1 && {
  nginx
}
# <<<<<<<<<<<<<<<<<<<< 脚本结束 <<<<<<<<<<<<<<<<<<<<
