#!/usr/bin/env bash
#
########################################
#  
#  NGINX Tool
#
########################################

source server/bash/common.sh

option="${2:-use-header}"

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
        if [[ -n "${NGINX_PID_PATH}" ]]; then
            if [[ -f ${NGINX_PID_PATH} ]]; then
                master_pid=$(cat ${NGINX_PID_PATH})
                ps -ax | awk '{print $1}' | grep -e "^${master_pid}$" > /dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    worker_pids=$(ps -o pid --no-headers --ppid ${master_pid} | xargs)
                        printf "$two_cols_table_format" "nginx" "*${master_pid}"
                    for worker_pid in ${worker_pids[@]}; do
                        printf "$two_cols_table_format" "nginx" "${worker_pid}"
                    done
                    exit 0
                else
                    printf "$two_cols_table_format" "nginx" "-"
                    exit 1
                fi
            fi 
        else
            master_pid=$(ps aux | grep nginx | grep master | grep -v 'grep' | grep -v 'nginx-tools' | awk '{print $2}' | xargs)
            if [[ -n "${master_pid}" ]]; then
                worker_pids=$(ps -o pid --no-headers --ppid ${master_pid} | xargs)
                printf "$two_cols_table_format" "nginx" "*${master_pid}"
                for worker_pid in ${worker_pids[@]}; do
                    printf "$two_cols_table_format" "nginx" "${worker_pid}"
                done
                exit 0
            fi
        fi
        exit 1
    ;;
    monitor)
        bash $0 status ${option}
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "nginx" "Process Not Found"
            printf "$two_cols_table_format" "nginx" "Starting..."
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
