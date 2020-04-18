#!/bin/bash
#
########################################
#
#  Jenkins Deploy Maven Project Script
#
########################################
#
# CLRF problem within win and linux:
#
# ```
# $ yum install dos2unix
# $ dos2unix the-file-that-be-warnned-CLRF
# ```
#--------------------------------------------
#
# scp without password authentication:
#
# receive rsa from *tomcat server*: `cat ~/.ssh/id_rsa.pub`
# add to *jenkins server*: `vim ~/.ssh/authorized_keys`
#--------------------------------------------
#

jenkins_project_name="SypDev-JavaAdmin"
project_war_path="portal-webapp/portal-admin/target/portal-admin-1.0-SNAPSHOT.war"

remote_server_ips=("api-dev.idata.mobi")
remote_backup_home="/data/backup/jenkins"
remote_war_filepath="/data/work/www/tomcatSuperAdmin/webapps/super-admin.war"
remote_ssh_user="sy-devops-user"
remote_ssh_port="22"
sypctl_tomcat_id="java-super-admin"

timestamp="$(date '+%Y%m%d%H%M%S')"
function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

# jenkins_war_path="/home/sy-devops-user/.jenkins/workspace/${jenkins_project_name}/${project_war_path}"
jenkins_war_path="${project_war_path}"

if [[ ! -f ${jenkins_war_path} ]]; then
    logger "ERROR - WAR 文件不存在: ${jenkins_war_path}"
    exit
fi

jenkins_war_filename=$(basename ${jenkins_war_path})
jenkins_war_filesize=$(du -sh ${jenkins_war_path} | awk '{ print $1 }')
remote_war_backup_path=${remote_backup_home}/${jenkins_war_filename}@${timestamp}

logger "=============================================="
logger "发布 ${jenkins_project_name} Web服务"
logger "${jenkins_war_filename}(${jenkins_war_filesize})"
logger "=============================================="
logger
for(( i=0; i<${#remote_server_ips[@]}; i++ )) do
    ip=${remote_server_ips[$i]}
    logger "> 启动子服务器, 开始 ${ip}"
    logger
    if ssh ${remote_ssh_user}@${ip} test ! -e "${remote_backup_home}"; then
        logger "中止操作，远程备份目录不存在: ${remote_backup_home}"
        exit 1
    fi
    logger "> 上传文件开始 ${jenkins_war_filename}(${jenkins_war_filesize})"
    scp -p -r ${jenkins_war_path} ${remote_ssh_user}@${ip}:${remote_war_backup_path}
    logger "< 上传文件结束 ${remote_war_backup_path}"
    logger
    if ssh ${remote_ssh_user}@${ip} test ! -e "${remote_war_backup_path}"; then
        logger "中止操作，远程 WAR 文件不存在: ${remote_war_backup_path}"
        exit 1
    fi
    logger "> 服务状态列表开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service status"
    logger "< 服务状态列表结束"
    logger
    logger "> 停止Web服务开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service stop ${sypctl_tomcat_id}"
    logger "< 停止Web服务结束"
    logger
    logger "> 更新/启动Web服务开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "rm -f ${remote_war_filepath} && cp -p ${remote_war_backup_path} ${remote_war_filepath}"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service start ${sypctl_tomcat_id}"
    logger "< 更新/启动消费者结束"
    logger 
    logger "> 服务状态列表开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service status"
    logger "< 服务状态列表结束"
    logger
    logger "< 启动子服务结束 ${ip}"
done
logger
logger "所有操作结束,启动可能还在进行中,请在dubbo监控台刷新"
logger