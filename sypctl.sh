#!/usr/bin/env bash

current_path="$(pwd)"
test -d /opt/scripts/syp-saas-scripts && cd /opt/scripts/syp-saas-scripts
source server/bash/common.sh

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
    package:status|ps)
        bash server/bash/packages-tools.sh state
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
        echo "same as execute bash below:"
        echo
        echo "curl -sS http://gitlab.ibi.ren/syp/syp-saas-scripts/raw/dev-0.0.1/env.sh | bash"
        echo 
        bash env.sh
    ;;
    bundle)
        cd server/rake
        echo "$ $@"
        $@
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
        bash server/bash/ambari-tools.sh install
    ;;
    memory:free|mf)
        fun_free_memory
    ;;
    firewalld:stop|fs)
        command -v systemctl > /dev/null 2>&1 && {
            systemctl stop iptables.service
            systemctl disable iptables.service
            systemctl stop firewalld.service
            systemctl disable firewalld.service
            iptables -L
        }
    ;;
    *)
        fun_print_sypctl_help
    ;;
esac

cd ${current_path}