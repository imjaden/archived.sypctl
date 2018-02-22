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
        pids=$(ps aux | grep nginx | grep -v 'grep' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            logger "nginx pids: ${pids}"
        else
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
