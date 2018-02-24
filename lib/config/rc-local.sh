
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
# <<<<<<<<<<<<<<<<<<<< 脚本结束 <<<<<<<<<<<<<<<<<<<<
