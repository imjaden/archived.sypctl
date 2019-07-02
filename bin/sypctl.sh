#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Controller
#
########################################
#

SYPCTL_EXECUTE_PATH="$(pwd)"
SYPCTL_BASH=$(readlink /usr/local/bin/sypctl)
SYPCTL_BIN=$(dirname ${SYPCTL_BASH})
SYPCTL_HOME=$(dirname ${SYPCTL_BIN})

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
    bundle)
        fun_execute_bundle_rake $@
    ;;
    report)
        ruby agent/lib/utils/wrapper.rb --mysql-report
        ruby agent/lib/utils/wrapper.rb --device-report
    ;;
    variable)
        fun_print_variable "$2"
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
    schedule-jobs:*)
        job=${1##*:}
        shift
        cd schedule-jobs
        mkdir -p {logs,db/$(date +'%y%m%d')}
        bash guard.sh ${job} $@ #>> logs/schedule-jobs.log 2>&1
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
    help)
        fun_sypctl_help
    ;;
    *)
        fun_name="fun_sypctl_$(echo $1 | sed 's/:/_/g')"
        type ${fun_name} > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            ${fun_name} $@
        else
            echo -e "未知参数 $1\n"
            fun_sypctl_help
        fi
    ;;
esac
cd ${SYPCTL_EXECUTE_PATH}
