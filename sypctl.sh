#!/usr/bin/env bash
#
########################################
#  
#  ShengYiPlus Controller
#
########################################
#
if [[ "$(uname -s)" = "Darwin" ]]; then
    SYPCTL_PREFIX=/usr/local/opt/
elif [[ "$(uname -s)" = "Linux" ]]; then
    SYPCTL_PREFIX=/usr/local/src/
else
    title "执行预检: 暂不兼容该系统 - $(uname -s)"
    exit 1
fi
SYPCTL_HOME=${SYPCTL_PREFIX}/sypctl
SYPCTL_EXECUTE_PATH="$(pwd)"
cd ${SYPCTL_HOME}

source platform/middleware.sh
case "$1" in
    version)
        echo "${sypctl_version}"
    ;;
    crontab:jobs|schedule:jobs)
        [[ $(date +%H%M) = "0000" ]] && sypctl upgrade
        [[ $(date +%H%M) = "0200" ]] && sypctl backup:mysql guard
        [[ $(date +%H%M) = "0400" ]] && sypctl backup:mysql killer

        bash $0 service     guard
        bash $0 agent:task  guard
        bash $0 agent:jobs  guard
        bash $0 backup:file guard
    ;;
    schedule-jobs)
        shift
        cd schedule-jobs && bash guard.sh $@ #>> logs/schedule-jobs.log 2>&1
    ;;
    bundle)
        fun_execute_bundle_rake $@
    ;;
    variable)
        fun_print_variable "$2"
    ;;
    home|info|env|network|upgrade|sync:device|deploy|deployed|clean|schedule:update|ssh:keygen|free:memory|disable:firewalld)
        operation=$(echo $1 | sed 's/:/_/g')
        fun_sypctl_${operation} $@
    ;;
    toolkit|service|backup:file|backup:mysql)
        operation=$(echo $1 | sed 's/:/_/g')
        fun_sypctl_${operation}_caller $@
    ;;
    app:*)
        fun_sypctl_app_caller $@
    ;;
    agent:*|agent)
        fun_sypctl_agent_caller $@
    ;;
    sync:mysql)
        shift
        ruby platform/ruby/sync-mysql-tools.rb $@
    ;;
    mode)
        test -f mode || echo default > mode
        echo "当前模式: $(cat mode)"
    ;;
    set-mode)
        read -p "设置 server 模式? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            echo server > mode
            echo "设置模式成功: server"
        else
            test -f mode || echo default > mode
            echo "当前模式: $(cat mode)"
        fi
    ;;
    *)
        fun_sypctl_help
    ;;
esac
cd ${SYPCTL_EXECUTE_PATH}
