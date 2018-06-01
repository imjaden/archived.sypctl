#!/usr/bin/env bash

current_path="$(pwd)"
test -n "$SYPCTL_HOME" && cd $SYPCTL_HOME || {
    test -d /opt/scripts/sypctl && cd /opt/scripts/sypctl
}

source linux/bash/common.sh

case "$1" in
    version)
        echo "${VERSION}"
    ;;
    git:pull|gp|upgrade|update)
        fun_upgrade
    ;;
    deploy)
        fun_deploy_service_guides
    ;;
    deployed)
        fun_print_deployed_services
    ;;
    start|stop|status|restart|monitor)
        fun_operator_service_process "$1"
    ;;
    guide|install:help|ih)
        fun_user_expect_to_install_package_guides
    ;;
    apk)
        bash android/tools.sh assemble "$2"
    ;;
    shengyiplus|ruishangplus|yh_android|shenzhenpoly)
        bash ios/tools.sh "$1"
    ;;
    env)
        fun_execute_env_script
    ;;
    bundle) # agent task
        fun_execute_bundle_rake $@
    ;;
    crontab) # sypctl crontab jobs
        fun_update_crontab_jobs
    ;;
    yum:kill)
        ps aux | grep yum | grep -v grep | awk '{ print $2 }' | xargs kill -9
    ;;
    yum:upgrade)
        yum provides '*/applydeltarpm'
        yum install -y deltarpm
        yum upgrade -y
    ;;
    ssh-keygen)
        fun_generate_sshkey_when_not_exist
    ;;
    ambari:install)
        bash linux/bash/ambari-tools.sh install
    ;;
    vnc:install)
        bash linux/bash/vnc-tools.sh install
    ;;
    redis:install)
        bash linux/bash/redis-tools.sh install
    ;;
    memory:free|mf)
        fun_free_memory
    ;;
    firewalld:stop|fs)
        fun_disable_firewalld
    ;;
    variable)
        fun_print_variable "$2"
    ;;
    agent:init)
        fun_init_agent "$2" "$3"
    ;;
    agent:job:daemon)
        fun_agent_job_daemon
    ;;
    linux:date:check)
        state=1
        trynum=1
        while [[ ${state} -gt 0 && ${trynum} -lt 4 ]]; do
            [[ ${trynum} -gt 1 ]] && echo "第 ${trynum} 次尝试校正系统时区"
            bash linux/bash/date-tools.sh
            state=$?
            trynum=$(expr ${trynum} + 1)
        done
    ;;
    *)
        fun_print_sypctl_help
    ;;
esac

cd ${current_path}