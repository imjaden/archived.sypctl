#!/usr/bin/env bash
#
########################################
#  
#  ShengYiPlus Controller
#
########################################
#
test -n "${SYPCTL_HOME}" || SYPCTL_HOME=/usr/local/src/sypctl
cd ${SYPCTL_HOME}
export SYPCTL_EXECUTE_PATH="$(pwd)"
source linux/bash/common.sh

mkdir -p {logs,tmp}
test -f mode || echo default > mode
sypctl_mode=$(cat mode)

case "$1" in
    version)
        echo "${VERSION}"
    ;;
    home)
        fun_print_logo
        echo " Version: ${VERSION}"
        echo "HomePath: ${SYPCTL_HOME}"
    ;;
    network)
        ping -c 1 sypctl.com > /dev/null 2>&1
        test $? -eq 0 && echo "网络正常" || echo "网络异常"
    ;;
    git:pull|gp|upgrade|update)
        fun_sypctl_upgrade
    ;;
    check:dependent:packages)
        fun_install_dependent_packages
    ;;
    device:update)
        fun_update_device
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
    env)
        fun_execute_env_script
    ;;
    bundle) # agent task
        fun_execute_bundle_rake $@
    ;;
    print_json)
        test -n "$2" && {
            cd agent
            json_path="$2"
            test -f "${json_path}" || {
                json_path="${SYPCTL_EXECUTE_PATH}/${json_path}"
            }
            bundle exec rake sypctl:print_json filepath="${json_path}"
        } || {
            echo "Warning: Please offer json filepath！"
        }
    ;;
    crontab:update|schedule:update)
        fun_update_crontab_jobs
        fun_update_rc_local
    ;;
    crontab:jobs|schedule:jobs)
        [[ $(date +%H%M) = "0000" ]] && sypctl upgrade
        [[ $(date +%H%M) = "0200" ]] && sypctl backup:mysql guard
        [[ $(date +%H%M) = "0400" ]] && sypctl backup:mysql killer

        bash $0 agent:task  guard
        bash $0 agent:jobs  guard
        bash $0 service     guard
        bash $0 backup:file guard
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
    memory:free|mf)
        fun_free_memory
    ;;
    firewalld:stop|fs)
        fun_disable_firewalld
    ;;
    variable)
        fun_print_variable "$2"
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
    toolkit)
        fun_toolkit_caller $@
    ;;
    service)
        fun_service_caller $@
    ;;
    backup:file)
        fun_backup_file_caller $@
    ;;
    backup:mysql)
        fun_backup_mysql_caller $@
    ;;
    sync:mysql)
        shift
        ruby linux/ruby/sync-mysql-tools.rb $@
    ;;
    app:*)
        fun_app_caller $@
    ;;
    agent:*|agent)
        fun_agent_caller $@
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
        fun_print_sypctl_help
    ;;
esac

cd ${SYPCTL_EXECUTE_PATH}
