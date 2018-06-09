#!/usr/bin/env bash
#
########################################
#  
#  Linux Date Tool
#
########################################

source linux/bash/common.sh
command -v rdate > /dev/null || fun_install rdate

case "$1" in
    check)
        if [[ "${os_type}" = "CentOS" || "${os_type}" = "RedHatEnterpriseServer" ]]; then
            rdate -pl -t 60 -s stdtime.gov.hk
        fi

        if [[ "${os_type}" = "Ubuntu" ]]; then
            rdate -ncv stdtime.gov.hk
        fi

        hwclock -w
    ;;
    view)
        date +'%z %m/%d/%y %H:%M:%S'
    ;;
    interval)
        test -z "$2" && {
            echo "Error: please pass a timestamp value as param!"
            exit 1
        }

        timestamp="$2"
        now=$(date +%s)
        echo "timestamp: ${timestamp}"
        echo "human: $(date -d @${timestamp} '+%y-%m-%d %H:%M:%S')"
        echo "interval: $(expr $now - $timestamp)s"
    *)
        echo "bash $0 view|check"
    ;;  
esac