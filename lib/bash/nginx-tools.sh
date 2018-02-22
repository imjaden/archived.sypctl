#!/usr/bin/env bash
#
########################################
#  
#  NGINX Tool
#
########################################

source lib/bash/common.sh

case "$1" in
    check)
        command -v nginx >/dev/null 2>&1 && fun_prompt_nginx_already_installed || {
            echo "warning: nginx command not found"
            exit 2
        }
    ;;
    install|deploy)
        command -v nginx >/dev/null 2>&1 && {
            fun_prompt_nginx_already_installed
            exit 1
        }

        yum install -y readline-devel gcc-c++ nginx
    ;;
    start|startup)
        bash $0 check
        test $? -eq 0 && {
            nginx
            test $? -eq 0 && bash $0 monitor
        }
    ;;
    stop)
        ps aux | grep nginx | grep -v 'grep' | awk '{print $2}' | xargs kill -9
    ;;
    restart)
        bash $0 stop
        bash $0 start
    ;;
    status|state)
        nginx_process_state=1
        if [[ -n "${NGINX_PID_PATH}" ]]; then
            if [[ -f ${NGINX_PID_PATH} ]]; then
                logger "nginx master(${NGINX_PID_PATH}) pid: $(cat ${NGINX_PID_PATH})"
                nginx_process_state=0
            fi 
        else
            master_pid=$(ps aux | grep nginx | grep master | grep -v 'grep' | grep -v 'nginx-tools' | awk '{print $2}' | xargs)
            if [[ -n "${master_pid}" ]]; then
                worker_pids=$(ps -o pid --no-headers --ppid ${master_pid} | xargs)
                printf "${status_header}" ${status_titles[@]}
                printf "%${status_width}.${status_width}s\n" "${status_divider}"
                printf "${status_format}" "nginx" "master" ${master_pid} "ps aux"
                for worker_pid in ${worker_pids[@]}; do
                    printf "${status_format}" "nginx" "worker" ${worker_pid} "ps -o pid --ppid"
                done
                nginx_process_state=0
            fi
        fi
        exit ${nginx_process_state}
    ;;
    monitor)
        bash $0 status 
        if [[ $? -gt 0 ]]; then
            logger "nginx process not found then start..."
            logger
            bash $0 start
        fi
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 check"
        logger "    $0 install"
        logger "    $0 start"
        logger "    $0 monitor"
        logger "    $0 check"
    ;;
esac
