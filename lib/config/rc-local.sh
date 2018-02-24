
# -----------------------------------------------
# 生意+ 项目进程，开机启动
# /etc/rc.d/rc.local
# -----------------------------------------------
# >>>>>>>>>>>>>>>>>>>> 脚本开始 >>>>>>>>>>>>>>>>>>>
cd /opt/scripts/syp-saas-scripts
sudo -u root bash tools.sh monitor 
sudo -u root crontab lib/config/syp@crontab.conf
# <<<<<<<<<<<<<<<<<<<< 脚本结束 <<<<<<<<<<<<<<<<<<<<
