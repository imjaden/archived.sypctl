#!/usr/bin/env bash
#
########################################
#  
#  Ambari Tool
#
########################################
#
# referenced: http://www.codeclip.com/3660.html
#
source server/bash/common.sh

case "$1" in
    install)
        test -f /etc/yum.repos.d/ambari.repo || {
          cd /etc/yum.repos.d/
          wget "http://public-repo-1.hortonworks.com/ambari/centos${os_version}/2.x/updates/2.2.1.0/ambari.repo"
        }

        command -v ambari-server > /dev/null 2>&1 && yum info ambari-server || yum install -y ambari-server
        command -v ambari-agent > /dev/null 2>&1 && yum info ambari-agent || yum install -y ambari-agent
    ;;
    start|startup)
        # ambari-server setup
        # ambari-server start
        # vim /etc/ambari-agent/conf/ambari-agent.ini
        echo "browser http://<ambari-server-host>:8080"
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 install"
    ;;
esac