
# -----------------------------------------------
# 生意+ 项目进程，开机启动
# /etc/rc.d/rc.local
# -----------------------------------------------
# >>>>>>>>>>>>>>>>>>>> 脚本开始 >>>>>>>>>>>>>>>>>>>
cd /opt/scripts/syp-saas-scripts
sudo -u root bash tools.sh monitor
sudo -u root crontab lib/config/syp@crontab.conf

cd /root/www/shengyiplus-server 
sudo -u root bash tool.sh start
sudo -u root bash tool.sh crontab:update

systemctl start mysqld.service
service iptables restart

systemctl daemon-reload
vncserver
systemctl enable vncserver@:1.service
systemctl start vncserver@:1.service
# <<<<<<<<<<<<<<<<<<<< 脚本结束 <<<<<<<<<<<<<<<<<<<<
