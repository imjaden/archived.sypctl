#!/usr/bin/env bash
#
########################################
#  
#  ShengYiPlus Controller
#
########################################
#
current_path="$(pwd)"
test -n "${SYPCTL_HOME}" || SYPCTL_HOME=/usr/local/src/sypctl
cd ${SYPCTL_HOME}
source linux/bash/common.sh

case "$1" in
    version)
        echo "${VERSION}"
    ;;
    home)
        fun_print_logo
        echo " Version: ${VERSION}"
        echo "HomePath: ${SYPCTL_HOME}"
    ;;
    git:pull|gp|upgrade|update)
        fun_upgrade
    ;;
    clean)
        fun_clean
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
    print_json)
        test -n "$2" && {
            cd agent
            bundle exec rake sypctl:print_json filepath="$2"
        } || {
            echo "Warning: Please offer json filepath！"
        }
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
    agent:server)
        fun_agent_server "$2" "$3"
    ;;
    agent:device)
        fun_agent_server "$2" "$3"
    ;;
    linux:date)
        bash linux/bash/date-tools.sh "$2" "$3"
    ;;
    toolkit)
        fun_toolkit_caller $@
    ;;
    etl:import)
        fun_etl_caller $@
    ;;
    etl:status)
        fun_etl_status $@
    ;;
    etl:tiny_tds)
        fun_etl_tiny_tds $@
    ;;
    *)
        fun_print_sypctl_help
    ;;
esac

cd ${current_path}