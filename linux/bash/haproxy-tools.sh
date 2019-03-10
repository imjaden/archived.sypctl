#!/usr/bin/env bash
#
########################################
#  
#  Haproxy Tool
#
########################################

source linux/bash/common.sh

case "$1" in
    check)
        rpm -qi haproxy
    ;;
    install)
        yum install -y haproxy
        mkdir -p /var/log/haproxy
        touch /var/log/haproxy/haproxy.log
        chmod a+w /var/log/haproxy/haproxy.log

        if [[ $(grep "haproxy.log" /etc/rsyslog.conf | wc -l) -eq 0 ]]; then
            echo "" >> /etc/rsyslog.conf
            echo "\$ModLoad imudp" >> /etc/rsyslog.conf
            echo "\$UDPServerRun 514" >> /etc/rsyslog.conf
            echo "local2.* /var/log/haproxy/haproxy.log" >> /etc/rsyslog.conf
            echo "" >> /etc/rsyslog.conf
        fi

        systemctl restart rsyslog
        systemctl restart haproxy
    ;;
    start)
        systemctl restart rsyslog
        systemctl start haproxy
    ;;
    status)
        systemctl status haproxy -l
    ;;
    stop)
        systemctl stop haproxy
    ;;
    monitor)
        # /var/run/haproxy.pid
    ;;
    help)
        echo "Haproxy 管理:"
        echo "$ sypctl toolkit haproxy help"
        echo "$ sypctl toolkit haproxy check"
        echo "$ sypctl toolkit haproxy install"
        echo "$ sypctl toolkit haproxy start"
        echo
        echo "# configration"
        echo "# example: ${SYPCTL_HOME}/linux/config/haproxy.cfg.example"
        echo "\$ vim /etc/haproxy/haproxy.cfg"
        echo "\$ vim /etc/rsyslog.conf"
        echo 

    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit mysql help
    ;;
esac



