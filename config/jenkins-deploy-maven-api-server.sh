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

jenkins_project_name="SypDev-JavaApiServer"
project_war_path="portal-webapp/portal-api/target/portal-api-1.0-SNAPSHOT.war"
project_jar_path="portal-api-service-parent/portal-api-service/target/portal-api-service-1.0-SNAPSHOT.jar"

remote_server_ips=("syp-dev.idata.mobi")
remote_backup_home="/data/backup/jenkins"
remote_war_filepath="/data/work/www/tomcatAPI/webapps/saas-api.war"
remote_jar_filepath="/data/work/www/providerAPI/api-service.jar"
remote_ssh_user="sy-devops-user"
remote_ssh_port="22"
sypctl_tomcat_id="java-api"
sypctl_provider_id="java-api-service"

timestamp="$(date '+%Y%m%d%H%M%S')"
function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

# jenkins_war_path="/home/sy-devops-user/.jenkins/workspace/${jenkins_project_name}/${project_war_path}"
# jenkins_jar_path="/home/sy-devops-user/.jenkins/workspace/${jenkins_project_name}/${project_jar_path}"
jenkins_war_path="${project_war_path}"
jenkins_jar_path="${project_jar_path}"

if [[ ! -f ${jenkins_war_path} || ! -f ${jenkins_jar_path} ]]; then
    logger "ERROR - war/jar 文件不存在:"
    logger "- ${jenkins_war_path}"
    logger "- ${jenkins_jar_path}"
    exit
fi

jenkins_war_filename=$(basename ${jenkins_war_path})
jenkins_jar_filename=$(basename ${jenkins_jar_path})
jenkins_war_filesize=$(du -sh ${jenkins_war_path} | awk '{ print $1 }')
jenkins_jar_filesize=$(du -sh ${jenkins_jar_path} | awk '{ print $1 }')
remote_war_backup_path=${remote_backup_home}/${jenkins_war_filename}@${timestamp}
remote_jar_backup_path=${remote_backup_home}/${jenkins_jar_filename}@${timestamp}

logger "=============================================="
logger "发布 ${jenkins_project_name} 平台消费者/提供者"
logger "${jenkins_war_filename}(${jenkins_war_filesize})"
logger "${jenkins_jar_filename}(${jenkins_jar_filesize})"
logger "=============================================="
logger
for(( i=0; i<${#remote_server_ips[@]}; i++ )) do
    ip=${remote_server_ips[$i]}
    logger "> 启动子服务器, 开始 ${ip}"
    logger
    logger "> 上传文件开始 ${jenkins_jar_filename}(${jenkins_jar_filesize})"
    scp -p -r ${project_jar_path} ${remote_ssh_user}@${ip}:${remote_jar_backup_path}
    logger "< 上传文件结束 ${remote_jar_backup_path}"
    logger
    logger "> 上传文件开始 ${jenkins_war_filename}(${jenkins_war_filesize})"
    scp -p -r ${jenkins_war_path} ${remote_ssh_user}@${ip}:${remote_war_backup_path}
    logger "< 上传文件结束 ${remote_war_backup_path}"
    logger
    logger "> 服务状态列表开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service status"
    logger "< 服务状态列表结束"
    logger
    logger "> 停止提供者开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service stop ${sypctl_provider_id}"
    logger "< 停止提供者结束"
    logger
    logger "> 更新/启动提供者开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "rm -f ${remote_jar_filepath}"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "cp -p ${remote_jar_backup_path} ${remote_jar_filepath}"
    timeout 15s ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service start ${sypctl_provider_id}"
    logger "< 更新/启动提供者结束"
    logger
    logger "> 停止消费者开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "sypctl service stop ${sypctl_tomcat_id}"
    logger "< 停止消费者结束"
    logger
    logger "> 更新/启动消费者开始"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "rm -f ${remote_war_filepath}"
    ssh -p $remote_ssh_port $remote_ssh_user@$ip "cp -p ${remote_war_backup_path} ${remote_war_filepath}"
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
