#!/usr/bin/env bash
#
########################################
#  
#  ShengYiPlus Controller
#
########################################
#
current_path="$(pwd)"
test -n "$SYPCTL_HOME" && cd $SYPCTL_HOME || {
    test -d /usr/local/src/sypctl && cd /usr/local/src/sypctl
}

source linux/bash/common.sh

case "$1" in
    version)
        echo "${VERSION}"
    ;;
    home)
        fun_print_logo
        echo " Version: ${VERSION}"
        echo "HomePath: $(test -n "${SYPCTL_HOME}" && echo ${SYPCTL_HOME} || echo /usr/local/src/sypctl)"
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
    rc.local)
        fun_update_rc_local
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
    agent:task)
        fun_execute_bundle_rake_without_logger bundle exec rake agent:$2
        [[ "$2" = "info" ]] && fun_print_crontab_and_rclocal
    ;;
    agent:job:daemon)
        fun_agent_job_daemon
    ;;
    linux:date)
        bash linux/bash/date-tools.sh "$2"
    ;;
    toolkit)
        test -z "$2" && {
            echo "Error: 请输入 sypctl 系统脚本名称！"
            echo
            echo "Usage: sypctl tookit <脚本名称> [参数]"
            echo
            echo "脚本列表："
            for tookit in $(ls linux/bash/*-tools.sh); do
                tookit=${tookit##*/}
                tookit=${tookit%-*}
            echo "- ${tookit}"
            done
            exit
        }

        toolkit=linux/bash/$2-tools.sh
        test -f ${toolkit} && {
            bash linux/bash/$2-tools.sh "$3" "$4"
        } || {
            echo "toolkit: ${tookit} 不存在，退出！"
            exit 1
        }
    ;;
    *)
        fun_print_sypctl_help
    ;;
esac

cd ${current_path}