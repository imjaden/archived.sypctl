
#!/usr/bin/env bash
#
########################################
#  
#  VNC Manager
#
########################################
#
source server/bash/common.sh

cmd_type="${1:-start}"
option="${2:-use-header}"

case "${cmd_type}" in 
    install|deploy)
        command -v vncserver >/dev/null 2>&1 && {
            fun_prompt_vncserver_already_installed
            exit 1
        }
        yum install -y tigervnc-server vnc
    ;;
    list|status)
        vncserver -list
    ;;
    start)
        vncserver
        systemctl enable vncserver@:1.service
        systemctl start vncserver@:1.service
    ;;
    stop)
        vncserver -list | grep -e ^: | awk '{ print $1 }' | xargs vncserver -kill
    ;;
    monitor)
        service_count=$(vncserver -list | grep -e ^: | wc -l)
        [[ ${service_count} -eq 0 ]] && bash $0 start
        bash $0 status
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 install|deplo"
        logger "    $0 list|status"
        logger "    $0 start"
        logger "    $0 stop"
        logger "    $0 monitor"
    ;;
esac