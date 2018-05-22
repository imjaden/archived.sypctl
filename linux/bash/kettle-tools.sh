#!/usr/bin/env bash
#
########################################
#  
#  Kettle Tool
#
########################################

source linux/bash/common.sh

case "$1" in
    install)
        test -d /usr/local/src/kettle || {
          cd /usr/local/src/
          wget "http://public-repo-1.hortonworks.com/ambari/centos${os_version}/2.x/updates/2.2.1.0/ambari.repo"
        }

        command -v kettle >/dev/null 2>&1  || {
            unlink /usr/bin/kettle
            ln -s /usr/local/src/kettle/spoon.sh /usr/bin/kettle
        }
        
        test -f /usr/share/applications/kettle.desktop && rm -f /usr/share/applications/kettle.desktop
        cp linux/config/kettle.desktop /usr/share/applications/
        chmod a+x /usr/share/applications/kettle.desktop
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 install"
    ;;
esac