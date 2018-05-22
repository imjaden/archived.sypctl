#!/usr/bin/env bash

current_path="$(pwd)"
test -d /opt/scripts/sypctl && cd /opt/scripts/sypctl
source linux/bash/common.sh

case "$1" in
    version)
        echo "${VERSION}"
    ;;
    git:pull|gp|upgrade|update)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
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
    bundle)
        fun_execute_bundle_utils_rake $@
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
    *)
        fun_print_sypctl_help
    ;;
esac

cd ${current_path}