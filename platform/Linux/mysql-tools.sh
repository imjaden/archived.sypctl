#!/usr/bin/env bash
#
########################################
#  
#  MySQL Tool
#
########################################

source platform/Linux/common.sh

case "$1" in
    check)
        mysql --help
    ;;
    install)
        command -v mysql >/dev/null 2>&1 && {
            mysql --help
            exit 0
        }

        case "${os_platform}" in
            CentOS6)
                sudo yum install -y mysql mysql-server
                sudo rpm -ivh http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
                sudo yum -y install nginx
            ;;
            CentOS7)
                sudo wget http://repo.mysql.com/mysql57-community-release-el7.rpm
                sudo rpm -ivh mysql57-community-release-el7.rpm
                sudo yum install -y mysql mysql-server

                echo "init mysql root password commands:"
                echo
                echo "\$ grep 'temporary password' /var/log/mysqld.log"
                echo "\$ mysql -u root -p"
                echo "mysql> SET PASSWORD = PASSWORD('root-password');"
                echo
            ;;
            Ubuntu16)  
                echo "TODO"
            ;;
            *)
                echo "MySQL 安装工具暂不支持该系统：${os_platform}"
            ;;
        esac
    ;;
    start)
        echo "TODO"
    ;;
    monitor)
        echo "TODO"
    ;;
    help)
        echo "MySQL 管理:"
        echo "$ sypctl toolkit mysql help"
        echo "$ sypctl toolkit mysql check"
        echo "$ sypctl toolkit mysql install"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit mysql help
    ;;
esac



