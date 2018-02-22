#!/usr/bin/env bash
#
########################################
#  
#  NGINX Tool
#
########################################

logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
function fun_prompt_nginx_already_installed() {
    echo >&2 "nginx already installed:"
    echo
    echo "$ which nginx"
    which nginx
    echo
    echo "$ nginx -v"
    nginx -v
    echo
    echo "$ nginx -t"
    nginx -t
}

case "$1" in
    check)
        command -v nginx >/dev/null 2>&1 && fun_prompt_nginx_already_installed || echo "warning: nginx command not found"
    ;;
    install|deploy)
        command -v nginx >/dev/null 2>&1 && {
            fun_prompt_nginx_already_installed
            exit 1
        }

        yum install -y readline-devel gcc-c++ nginx
    ;;
    start|startup)
        nginx
    ;;
    stop)
        ps aux | grep nginx | grep -v 'grep' | awk '{print $2}' | xargs kill -9
    ;;
    restart)
        bash $0 stop
        bash $0 start
    ;;
    monitor)
        nginx_process_state=0
        if [[ -n "${NGINX_PID_PATH}" ]]; then
            if [[ -f ${NGINX_PID_PATH} ]]; then
                logger "nginx master(${NGINX_PID_PATH}) pid: $(cat ${NGINX_PID_PATH})"
                nginx_process_state=1
            fi 
        else
            pids=$(ps aux | grep nginx | grep -v 'grep' | awk '{print $2}' | xargs)
            if [[ -n "${pids}" ]]; then
                logger "nginx pids: ${pids}"
                nginx_process_state=1
            fi
        fi

        if [[ ${nginx_process_state} -eq 0 ]]; then
            logger "nginx process not found then start..."
            logger
            bash $0 start
            logger
            logger "check nginx process..."
            logger
            bash $0 monitor
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
