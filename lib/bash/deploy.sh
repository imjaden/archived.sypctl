#!/bin/bash
########################################
#  
#  Deploy Tools
#
########################################

logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

deploy_scripts() {
    local ssh_port=$1
    local ssh_user=$2
    local ssh_ip=$3

    logger "-----------------------------"
    logger ${ssh_user}@${ssh_ip}
    logger "-----------------------------"

    logger "mkdir -p /opt/scripts"

    logger "上传各服务管理脚本"
    ssh -p $ssh_port $ssh_user@$ssh_ip "mkdir -p /opt/scripts"
    for script in $(ls *); do
        scp -P ${ssh_port} ${script} ${ssh_user}@${ssh_ip}:/opt/scripts
        scp -P ${ssh_port} ${script} ${ssh_user}@${ssh_ip}:~/tools
    done

    logger "上传软件安装包"
    ssh -p $ssh_port $ssh_user@$ssh_ip "mkdir -p ~/tools"
    for file in $(ls ../packages/*.tar.gz); do
        scp -P ${ssh_port} ../packages/${file} ${ssh_user}@${ssh_ip}:~/tools
    done

    echo "配置 java 环境"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cd ~/tools && bash /opt/scripts/jdk-tools.sh"
    echo "配置 zookeeper 环境"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cd ~/tools && bash /opt/scripts/zookeeper-tools.sh /usr/local/src/zookeeper install"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp ~/tools/zoo.cfg /usr/local/src/zookeeper/conf/zoo.cfg"

    ssh -p $ssh_port $ssh_user@$ssh_ip "cd ~/tools && tar -xzvf apache-tomcat-8.5.24.tar.gz"
    echo "配置 tomcatAPI"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp -rf ~/tools/apache-tomcat-8.5.24 /usr/local/src/tomcatAPI"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp ~/tools/setting-8081.xml /usr/local/src/tomcatAPI/conf/server.xml"
    echo "配置 tomcatSuperAdmin"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp -rf ~/tools/apache-tomcat-8.5.24 /usr/local/src/tomcatSuperAdmin"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp ~/tools/setting-8082.xml /usr/local/src/tomcatSuperAdmin/conf/server.xml"
    echo "配置 tomcatAdmin"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp -rf ~/tools/apache-tomcat-8.5.24 /usr/local/src/tomcatAdmin"
    ssh -p $ssh_port $ssh_user@$ssh_ip "cp ~/tools/setting-8083.xml /usr/local/src/tomcatAdmin/conf/server.xml"
    echo "配置 API Service"
    ssh -p $ssh_port $ssh_user@$ssh_ip "mkdir -p /usr/local/src/providerAPI"
}

read -p "请输入 ssh 登录的端口：（默认 22）" ssh_port
read -p "请输入 ssh 登录的用户名：" ssh_user
read -p "请输入 ssh 登录的 ip：" ssh_ip

deploy_scripts ${ssh_port} ${ssh_user} ${ssh_ip}