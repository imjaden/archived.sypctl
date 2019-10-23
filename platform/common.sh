#!/usr/bin/env bash

export LANG=zh_CN.UTF-8

SYSTEM_SHELL=${SHELL##*/}
SHELL_PROFILE=

function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
function title() { printf "########################################\n# %s\n########################################\n" "$1"; }
function fun_printf_timestamp() { printf "\n Timestamp: $(date +'%Y-%m-%d %H:%M:%S')\n"; }

SYPCTL_BRANCH=dev-0.0.1
SYPCTL_BASH=$(readlink /usr/local/bin/sypctl)
SYPCTL_BIN=$(dirname ${SYPCTL_BASH})
SYPCTL_HOME=$(dirname ${SYPCTL_BIN})
command -v sypctl > /dev/null 2>&1 || export PATH="/usr/local/bin:$PATH"

cd ${SYPCTL_HOME}
mkdir -p {logs,tmp,packages}
test -f mode || echo default > mode

sypctl_version=$(cat version)
sypctl_mode=$(cat mode)
current_user=$(whoami)

current_group=$(groups ${current_user} | awk '{ print $1 }')
timestamp=$(date +'%Y%m%d%H%M%S')
timestamp2=$(date +'%y-%m-%d %H:%M:%S')

function fun_sypctl_network() {
    ping -c 1 sypctl.com > /dev/null 2>&1
    test $? -eq 0 && return 0

    title "网络预检：无网络环境，退出操作"
    return 1
}

function fun_sypctl_pre_upgrade() {
    fun_sypctl_network || exit 1
    
    gitlab_version=$(curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/version)
    release_version=${gitlab_version##*.} 
    if [[ "${sypctl_version}" = "${gitlab_version}" ]]; then
        title "升级预检: 当前版本已是最新版本"
        sypctl home
        return 1
    else
        if [[ "${release_version}" = "8" ]]; then
            title "升级预检: 有发布新版本 ${gitlab_version}, 当前版本 ${sypctl_version}, 进行升级操作"
            return 0
        else
            title "升级预检: 有发布测试版本 ${gitlab_version}, 暂不操作"
            sypctl home
            return 1
        fi
    fi
}

function fun_sypctl_update_env_files() {
    if [[ "${SYSTEM_SHELL}" = "zsh" ]]; then
        SHELL_PROFILE=${HOME}/.zshrc
    elif [[ "${SYSTEM_SHELL}" = "bash" ]] || [[ "${SYSTEM_SHELL}" = "sh" ]]; then
        SHELL_PROFILE=${HOME}/.bash_profile
    else
        title "执行预检: 暂未兼容该SHEEL - ${SYSTEM_SHELL}"
        exit 1
    fi

    cd ${SYPCTL_HOME}
    echo "${SHELL_PROFILE}" >> .env-files
    cat .env-files | uniq > .env-files-uniq
    mv .env-files-uniq .env-files
    if [[ $(grep "\$HOME/.rbenv/bin" ${SHELL_PROFILE} | wc -l) -gt 0 ]]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ${SHELL_PROFILE}
        echo 'eval "$(rbenv init -)"' >> ${SHELL_PROFILE}
        source ${SHELL_PROFILE} > /dev/null 2>&1
    fi
}

#
# sypctl 版本升级后的处理逻辑
#
function fun_sypctl_upgrade_action() {
    old_version=$(sypctl version)
    git reset --hard HEAD
    git pull origin ${SYPCTL_BRANCH} > /dev/null 2>&1

    test "${current_user}" != "root" && chown -R ${current_user}:${current_group} ${SYPCTL_HOME}
    chmod -R +w ${SYPCTL_HOME}
    chmod -R +x ${SYPCTL_HOME}/bin/

    # force relink /usr/local/bin/
    sypctl_commands=(sypctl syps sypt)
    for sypctl_command in ${sypctl_commands[@]}; do
        command -v ${sypctl_command} > /dev/null 2>&1 && rm -f $(which ${sypctl_command})
        ln -snf ${SYPCTL_HOME}/bin/${sypctl_command}.sh /usr/local/bin/${sypctl_command}
    done

    fun_sypctl_update_env_files
    fun_sypctl_check_dependent_packages

    # 编译 sypctl 代理端服务
    # bundle 操作必须执行，所 ruby 脚本依赖的包都维护在该 Gemfile 中
    cd agent
    mkdir -p {monitor/{index,pages},logs,tmp/pids,db,.config}
    rm -f .config/bundle-done
    bundle install > /dev/null 2>&1
    test $? -eq 0 && echo ${timestamp} > .config/bundle-done
    test -f .config/local-server && bash tool.sh restart
    cd ..

    if [[ "${old_version}" = "$(sypctl version)" ]]; then
        fun_print_logo
        title "current version ${old_version} already is latest version!"
        exit 1
    fi

    if [[ "${sypctl_mode}" = "server" ]]; then
        # 升级后重新提交主机信息
        test -f agent/db/agent.json && mv agent/db/agent.json agent/db/agent.json-${timestamp}

        # 升级生重新备份配置档
        test -f agent/db/file-backups/synced.hash && mv agent/db/file-backups/synced.hash agent/db/file-backups/synced.hash-${timestamp}
        test -f agent/db/file-backups/synced.json && mv agent/db/file-backups/synced.json agent/db/file-backups/synced.json-${timestamp}

        # 升级后重要实时同步的操作
        sypctl toolkit date check > /dev/null 2>&1
        sypctl memory:free > /dev/null 2>&1
        sypctl schedule:update > /dev/null 2>&1
        sypctl schedule:jobs > /dev/null 2>&1
    fi

    title "upgrade from ${old_version} => $(sypctl version) successfully!"
    ruby platform/ruby/behavior.rb --old="${old_version}" --new="$(sypctl version)" > /dev/null 2>&1

    sypctl help
}

#
# 强制升级，跳过版本检查
#
function fun_sypctl_upgrade_force() {
    fun_sypctl_upgrade_action
}

#
# 强制升级，跳过版本检查
#
function fun_sypctl_upgrade() {
    fun_sypctl_pre_upgrade || exit 1
    fun_sypctl_upgrade_action
}

function fun_sypctl_help() {
    echo "Usage: sypctl <command> [args]"
    echo 
    echo "常规操作:"
    echo "sypctl help              帮助说明"
    echo "sypctl upgrade           更新源码"
    echo "sypctl upgrade:force     强制更新"
    echo "sypctl deploy            部署服务引导（删除会自动部署）"
    echo "sypctl deployed          查看已部署服务"
    echo "sypctl report            设备/MySQL状态"
    echo "sypctl sync:device       更新重新提交设备信息"
    echo
    echo "sypctl agent   help      #代理# 配置"
    echo "sypctl toolkit help      #工具# 箱"
    echo "sypctl service help      #服务# 管理"
    echo "sypctl backup:file  help #备份文件# 工具"
    echo "sypctl backup:mysql help #备份MySQL# 工具"
    echo "sypctl sync:mysql   help #迁移MySQL# 工具"
    echo
    echo "命令缩写:"
    echo "sypctl service -> syps"
    echo "sypctl toolkit -> sypt"
    echo
    fun_print_logo
    echo "Current version is ${sypctl_version}"
    echo "For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git"
}

function fun_print_logo() {
    # figlet SYPCTL
    # toilet SYPCTL
    echo 
    echo '  mmmm m     m mmmmm    mmm mmmmmmm m'
    echo ' #"   " "m m"  #   "# m"   "   #    #'
    echo ' "#mmm   "#"   #mmm#" #        #    #'
    echo '     "#   #    #      #        #    #'
    echo ' "mmm#"   #    #       "mmm"   #    #mmmmm'
    echo
}

function fun_print_init_agent_help() {
    echo "Usage: sypctl <command> [<args>]"
    echo 
    fun_print_init_agent_command_help
    echo 
    echo "Current version is ${sypctl_version}"
    echo "For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git"
}

function fun_print_init_agent_command_help() {
    echo "代理配置:"
    echo "sypctl agent:init help"
    echo "sypctl agent:init uuid <arg>       自定义设备UUID"
    echo "sypctl agent:init human_name <arg> 自定义设备名称"
    echo "sypctl agent:init title <arg>      自定义Web服务标题"
    echo "sypctl agent:init favicon <arg>    自定义Web服务favicon"
    echo "sypctl agent:init list             初始化配置信息列表"
    echo
    echo "任务操作:"
    echo "sypctl agent:task guard          代理守护者，注册、提交功能"
    echo "sypctl agent:task info           查看注册信息"
    echo "sypctl agent:task render         查看将要注册的信息"
    echo "sypctl agent:task log            查看提交日志"
    echo "sypctl agent:task device         对比设备信息与已注册信息（调整硬件时使用）"
    echo "sypctl agent:jobs guard          服务器端任务的监护者"
    echo "sypctl agent:jobs doing          查看正在执行任务列表"
    echo "sypctl agent:jobs view [uuid]   查看任务明细信息"
    echo
    echo "代理端服务:"
    echo "sypctl agent:server help         帮助说明"
    echo "sypctl agent:server deploy       部署引导"
    echo "sypctl agent:server deploy:force 强制重新部署"
    echo "sypctl agent:server start        启动服务"
    echo "sypctl agent:server stop         关闭服务"
    echo "sypctl agent:server restart      重启服务"
    echo "sypctl agent:server status       服务状态"
    echo "sypctl agent:server disable      禁用服务"
}

function fun_print_app_command_help() {
    echo "sypctl app:config init"
    echo "sypctl app:config app.uuid {{app.uuid}}"
    echo "sypctl app:config app.name {{app.uuid}}"
    echo "sypctl app:config app.file_name {{app.file_name}}"
    echo "sypctl app:config app.file_path {{app.file_path}}"
    echo "sypctl app:config version.uuid {{app.latest_version.uuid}}"
    echo "sypctl app:config version.name {{app.latest_version.version}}"
    echo "sypctl app:config version.backup_path /data/backup/"
    echo "sypctl app:deploy"
}

function fun_print_sypctl_service_help() {
    echo "服务管理:"
    echo "sypctl service list      查看管理的服务列表"
    echo "sypctl service check     检查配置是否正确"
    echo "sypctl service start     启动服务列表中的应用"
    echo "sypctl service status    检查服务列表应用的运行状态"
    echo "sypctl service stop      关闭服务列表中的应用"
    echo "sypctl service restart   重启服务列表中的应用"
    echo "sypctl service enable    激活服务列表中的应用"
    echo "sypctl service disable   禁用服务列表中的应用"
    echo "sypctl service monitor   监控列表中的服务，未运行则启动"
    echo "sypctl service install   安装服务配置"
    echo "sypctl service uninstall 卸载服务配置"
    echo "sypctl service guard     守护监控服务配置"
}

function fun_print_sypctl_backup_file_help() {
    echo "sypctl backup:file help     帮助说明"
    echo "sypctl backup:file list     查看备份列表"
    echo "sypctl backup:file render   查看元信息"
    echo "sypctl backup:file execute  执行备份操作"
    echo "sypctl backup:file guard    守护备份操作，功能同 execute"
}

function fun_print_sypctl_backup_mysql_help() {
    echo "sypctl backup:mysql help     帮助说明"
    echo "sypctl backup:mysql list     查看备份配置"
    echo "sypctl backup:mysql check    检查配置档状态"
    echo "sypctl backup:mysql view     执行今日备份状态"
    echo "sypctl backup:mysql state    进程状态"
    echo "sypctl backup:mysql execute  执行备份操作"
    echo "sypctl backup:mysql guard    守护备份操作，功能同 execute"
}

function fun_sypctl_home() {
    fun_print_logo
    echo "  Version: ${sypctl_version}"
    echo " HomePath: ${SYPCTL_HOME}"
    echo " DiskSize: $(du -sh ${SYPCTL_HOME} | cut -f 1 | sed s/[[:space:]]//g)"
    echo "Timestamp: ${timestamp2}"

    while read filepath; do
        echo "  EnvFile: ${filepath}"
    done < .env-files
}

#
# 同步设备信息至服务器
#
function fun_sypctl_sync_device() {
    echo "\$ cd agent"
    cd agent
    mkdir -p {monitor/{index,pages},logs,tmp/pids,db/{jobs,versions},.config}
    echo "\$ bundle install ..."
    bundle install > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      echo "\$ bundle install --local successfully"
      echo ${timestamp} > .config/bundle-done
    fi

    # 旧 device uuid 作为初始化 uuid, 以避免 devuce uuid 生成策略调整；
    # 即支持 device uuid 更新
    if [[ -f device-uuid ]]; then
        echo "\$ mv device-uuid init-uuid"
        test -f device-uuid && mv device-uuid init-uuid
    fi
    
    # 升级后重新注册
    test -f db/agent.json && mv db/agent.json tmp/agent.json-${timestamp}

    echo "\$ bundle exec rake agent:guard"
    bundle exec rake agent:guard

    echo "\$ bundle exec rake agent:device"
    bundle exec rake agent:device
}

function fun_sypctl_agent_caller() {
    mkdir -p agent/db/jobs
    
    main_type="$1"
    shift
    sub_type="$1"
    shift
    case "${main_type}" in
        agent)
            fun_print_init_agent_command_help
        ;;
        agent:init)
            fun_init_agent "${sub_type}" "$@"
        ;;
        agent:task)
            [[ "${sub_type}" = "service" ]] && sypctl service monitor
            fun_execute_bundle_rake_without_logger bundle exec rake agent:${sub_type} $@
        ;;
        agent:jobs)
            case "${sub_type}" in
                doing)
                    fun_agent_job_doing
                ;;
                view)
                    fun_agent_job_view $@
                ;;
                guard)
                    fun_agent_job_guard
                ;;
                *)
                    echo "Error - unknown command: ${sub_type}"
                    echo
                    echo
                    fun_print_init_agent_command_help
                ;;
            esac
        ;;
        agent:server)
            fun_agent_server "$sub_type" $@
        ;;
        *)
            echo "Error - unknown command: $@"
        ;;
    esac
}

function fun_sypctl_sendmail_caller() {
    shift
    SYPCTL_HOME=${SYPCTL_HOME} RAKE_ROOT_PATH=${SYPCTL_HOME}/agent ruby platform/ruby/mail-tools.rb $@
}

function fun_sypctl_service_caller() {
    if [[ "${2}" = "help" ]]; then
        fun_print_sypctl_service_help
        exit 1
    fi

    mkdir -p /etc/sypctl/
    support_commands=(render list check start stop status restart enable disable monitor edit guard install uninstall)
    if [[ "$2" = "edit" ]]; then
        vim /etc/sypctl/services.json
    elif [[ "${support_commands[@]}" =~ "$2" ]]; then
        SYPCTL_HOME=${SYPCTL_HOME} RAKE_ROOT_PATH=${SYPCTL_HOME}/agent ruby platform/ruby/service-tools.rb "--$2" "${3:-all}"
    else
        echo "Error - 未知参数: $2, 仅支持: ${support_commands[@]}"
    fi
}

function fun_sypctl_env() {
    echo "same as execute bash below:"
    echo
    echo "curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/env.sh | bash"
    echo 
    bash env.sh
}

function fun_sypctl_schedule_update() {
    fun_update_crontab_jobs
    fun_update_rc_local
}

#
# 自定义初始化 agent 配置
#
function fun_init_agent() {
    test -d agent/.config || mkdir -p agent/.config
    case "$1" in
        uuid)
            test -n "$2" && {
                echo "$2" > agent/.config/init-uuid
                rm -f agent/db/agent.json
            } || sypctl agent:init help
        ;;
        title)
            test -n "$2" && {
                echo "$2" > agent/.config/web-title
            } || sypctl agent:init help
        ;;
        favicon)
            test -n "$2" && {
                echo "$2" > agent/.config/web-favicon
            } || sypctl agent:init help
        ;;
        human_name)
            test -n "$2" && {
                echo "$2" > agent/.config/human-name
                rm -f agent/db/agent.json
                sypctl agent:task guard
                sypctl agent:task info
            } || sypctl agent:init help
        ;;
        list)
            echo "uuid       : $([[ -f agent/.config/init-uuid ]] && cat agent/.config/init-uuid || echo 'NotConfig')"
            echo "human_name : $([[ -f agent/.config/human_name ]] && cat agent/.config/human_name || echo 'NotConfig')"
            echo "title      : $([[ -f agent/.config/web-title ]] && cat agent/.config/web-title || echo 'NotConfig')"
            echo "favicon    : $([[ -f agent/.config/web-favicon ]] && cat agent/.config/web-favicon || echo 'NotConfig')"
        ;;
        help)
            fun_print_init_agent_help
        ;;
        *)
            fun_print_init_agent_help
        ;;
    esac
}

function fun_execute_bundle_rake() {
    echo "$ $@ ..."

    cd agent
    test -f .config/bundle-done || {
        bundle install
        if [[ $? -eq 0 ]]; then
          echo "$ bundle install --local successfully"
          echo ${timestamp} > .config/bundle-done
        fi
    }

    [[ `uname -s` = "Darwin" ]] && {
        test -d logs || mkdir logs && { 
            log_count=$(ls logs/ | grep '.log' | wc -l)
            if [[ $log_count -gt 0 ]]; then
                archived_path=tmp/archived/${timestamp}
                mkdir -p ${archived_path}
                mv logs/*.log ${archived_path}/
            fi
        }
        $@
        exit
    }
    
    test -d logs || mkdir logs
    logpath=logs/task_agent-${timestamp}.log
    executed_date=$(date +%s)

    $@ >> ${logpath} 2>&1

    finished_date=$(date +%s)
    echo "executed $(expr $finished_date - $executed_date) seconds"
    echo "see log with command:"
    echo "\$ cat $(pwd)/${logpath}"
}

function fun_execute_bundle_rake_without_logger() {
    echo "$ $@ ..."

    cd agent
    test -f .config/bundle-done || {
        bundle install --local > /dev/null
        if [[ $? -eq 0 ]]; then
            mkdir -p .config
            echo ${timestamp} > .config/bundle-done
        else
            bundle install > /dev/null
        fi
    }

    test -f .config/local-server && bash tool.sh process:defender
    $@
    cd ..
}

function fun_print_variable() {
    variable="$1"
    test -z $variable && {
        echo "please input variable name"
        return 1
    }
    eval "echo \${$variable}"
}

#
# agent server
#
function fun_agent_server_daemon() {
    cd agent

    bash tool.sh process:defender
}
function fun_agent_server() {
    cd agent
    bash tool.sh "$1"
    cd ..
}

#
# 代理执行服务器端分发的任务脚本
#
function fun_agent_job_guard() {
    if [[ $(find agent/db/jobs/ -name '*.todo' | wc -l) -eq 0 ]]; then
        echo '#等待执行# 任务列表为空'
    else
        # 遍历待做任务
        for todo_job_tag in $(ls agent/db/jobs/*.todo); do
            job_uuid=$(cat $todo_job_tag)
            bash_path=agent/db/jobs/${job_uuid}/job.sh
            pid_path=agent/db/jobs/${job_uuid}/job.pid
            output_path=agent/db/jobs/${job_uuid}/job.output
            doing_job_tag="${todo_job_tag%.*}.doing"
            done_job_tag="${todo_job_tag%.*}.done"

            # 1. 定时任务每五分钟扫描一次待做任务
            # 2. 每个任务可能耗时超出五分钟，下个定时扫描会执行一个任务，
            #    在前N 个定时扫描遍历中时应该避免后续被执行的任务
            if [[ -f ${todo_job_tag} ]]; then
                echo $$ > ${pid_path}
                mv ${todo_job_tag} ${doing_job_tag}

                echo "${timestamp2} - Bash PID: $$" >> ${output_path} 2>&1
                echo "${timestamp2} - Bash User: ${whoami}" >> ${output_path} 2>&1
                echo "${timestamp2} - 任务 UUID: ${job_uuid}" >> ${output_path} 2>&1
                echo "${timestamp2} - 部署脚本执行开始: $(date +'%Y-%m-%d %H:%M:%S')" >> ${output_path} 2>&1

                if [[ -f ${bash_path} ]]; then
                    while read bash_line; do
                        if [[ -n ${bash_line} ]]; then
                            echo "${timestamp2} - \$ ${bash_line} ${job_uuid}" >> ${SYPCTL_HOME}/${output_path} 2>&1
                            ${bash_line} ${job_uuid} >> ${SYPCTL_HOME}/${output_path}.bundle 2>&1
                            echo "${timestamp2} - " >> ${SYPCTL_HOME}/${output_path} 2>&1
                        fi
                    done < ${bash_path}
                    cd ${SYPCTL_HOME}
                else
                    echo "${timestamp2} - 脚本不存在：${bash_path}" >> ${output_path} 2>&1
                fi

                echo "${timestamp2} - 部署脚本执行完成: $(date +'%Y-%m-%d %H:%M:%S')" >> ${output_path} 2>&1
                echo "${timestamp2} - " >> ${output_path} 2>&1
                echo "${timestamp2} - 提交部署状态至服务器" >> ${output_path} 2>&1
                sypctl bundle exec rake agent:job uuid=${job_uuid} >> ${output_path} 2>&1

                mv ${doing_job_tag} ${done_job_tag}
            fi
        done
    fi

    if [[ $(find agent/db/jobs/ -name '*.doing' | wc -l) -eq 0 ]]; then
        echo '#正在执行# 任务列表为空'
    else
        # 遍历正在执行任务，救火中断的任务
        for doing_job_tag in $(ls agent/db/jobs/*.doing); do
            job_uuid=$(cat $doing_job_tag)
            bash_path=agent/db/jobs/${job_uuid}/job.sh
            pid_path=agent/db/jobs/${job_uuid}/job.pid
            output_path=agent/db/jobs/${job_uuid}/job.output
            done_job_tag="${doing_job_tag%.*}.done"

            # 1. 定时任务每五分钟扫描一次待做任务
            # 2. 每个任务可能耗时超出五分钟，下个定时扫描会执行一个任务，
            #    在前N 个定时扫描遍历中时应该避免后续被执行的任务
            if [[ -f ${doing_job_tag} ]]; then
                # 任务中断的判断条件:
                # 1. 无pid 文件
                # 2. pid 查询不到
                process_state="abort"
                if [[ -f "${pid_path}" ]]; then
                    pid=$(cat ${pid_path})
                    ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
                    test $? -eq 0 && process_state="running"
                fi

                # 重新执行中断的任务
                if [[ "${process_state}" = "abort" ]]; then
                    echo $$ > ${pid_path}
                    echo "${timestamp2} - 重新执行中断的任务" >> ${output_path} 2>&1
                    echo "${timestamp2} - Bash 进程 ID: $$" >> ${output_path} 2>&1
                    echo "${timestamp2} - 任务 UUID: ${job_uuid}" >> ${output_path} 2>&1
                    echo "${timestamp2} - 部署脚本执行开始: $(date +'%Y-%m-%d %H:%M:%S')" >> ${output_path} 2>&1

                    if [[ -f ${bash_path} ]]; then
                        while read bash_line; do
                            if [[ -n ${bash_line} ]]; then
                                echo "${timestamp2} - \$ ${bash_line} ${job_uuid}" >> ${SYPCTL_HOME}/${output_path} 2>&1
                                ${bash_line} ${job_uuid} >> ${SYPCTL_HOME}/${output_path}.bundle 2>&1
                                echo "${timestamp2} - " >> ${SYPCTL_HOME}/${output_path} 2>&1
                            fi
                        done < ${bash_path}
                        cd ${SYPCTL_HOME}
                    else
                        echo "${timestamp2} - 脚本不存在：${bash_path}" >> ${output_path} 2>&1
                    fi

                    echo "${timestamp2} - 部署脚本执行完成: $(date +'%Y-%m-%d %H:%M:%S')" >> ${output_path} 2>&1
                    echo "${timestamp2} - " >> ${output_path} 2>&1
                    echo "${timestamp2} - 提交部署状态至服务器" >> ${output_path} 2>&1
                    sypctl bundle exec rake agent:job uuid=${job_uuid} >> ${output_path} 2>&1

                    mv ${doing_job_tag} ${done_job_tag}
                fi
            fi
        done
    fi
}

function fun_agent_job_doing() {
    if [[ $(find agent/db/jobs/ -name '*.doing' | wc -l) -eq 0 ]]; then
        echo '没有正在执行的任务'
        exit 1
    fi

    for filepath in $(ls agent/db/jobs/*.doing); do
        job_uuid=$(cat $filepath)
        pid_path=agent/db/jobs/${job_uuid}/job.pid

        # 任务中断的判断条件:
        # 1. 无pid 文件
        # 2. pid 查询不到
        process_state="任务中断"
        if [[ -f "${pid_path}" ]]; then
            pid=$(cat ${pid_path})
            ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
              process_state="任务执行中(${pid})"
            fi
        fi
        
        echo
        echo "任务UUID: ${job_uuid}"
        echo "进程状态: ${process_state}"
        echo "进程 ID: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.pid"
        echo "任务配置: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.json"
        echo "部署执行: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.sh"
        echo "部署日志: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.output"
        echo "执行日志: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.output.bundle"
        echo
    done
}

function fun_agent_job_view() {
    job_uuid=$1
    job_home=agent/db/jobs/${job_uuid}

    if [[ -z "${job_uuid}" ]]; then
        echo "请提供任务 UUID"
        echo
        fun_print_init_agent_command_help
        exit 1
    fi

    if [[ -d ${job_home} ]]; then
        pid_path=agent/db/jobs/${job_uuid}/job.pid

        # 任务中断的判断条件:
        # 1. 无pid 文件
        # 2. pid 查询不到
        process_state="任务中断"
        if [[ -f "${pid_path}" ]]; then
            pid=$(cat ${pid_path})
            ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
              process_state="任务执行中(${pid})"
            fi
        fi
        
        echo
        echo "任务UUID: ${job_uuid}"
        echo "进程状态: ${process_state}"
        echo "进程 ID: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.pid"
        echo "任务配置: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.json"
        echo "部署执行: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.sh"
        echo "部署日志: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.output"
        echo "执行日志: ${SYPCTL_HOME}/agent/db/jobs/${job_uuid}/job.output.bundle"
        echo
    else
        echo "在本机查询任务失败，UUID=${job_uuid}"
    fi
}

function fun_print_toolkit_list() {
    echo "使用说明:"
    echo "$ sypctl toolkit [name] source   # 查看脚本源码"
    echo "$ sypctl toolkit [name] [args]   # 脚本功能参数"
    echo
    echo "工具列表:"
    printf "\$ sypctl toolkit %-10s help\n" "package"
    for tookit in $(ls platform/$(uname -s)/*-tools.sh); do
        tookit=${tookit##*/}
        tookit=${tookit%-*}
        printf "\$ sypctl toolkit %-10s help\n" ${tookit}
    done
    echo
}

function fun_sypctl_toolkit_caller() {
    if [[ -z "$2" || "$2" = "help" ]]; then
        fun_print_toolkit_list
        exit 1
    fi

    toolkit_name="$2"
    toolkit_command="$3"
    toolkit_path=platform/$(uname -s)/${toolkit_name}-tools.sh
    test -f ${toolkit_path} && {
        if [[ "${toolkit_command}" = "source" ]]; then
            echo "\$ cd $(pwd)"
            echo "\$ cat ${toolkit_path}"
            cat ${toolkit_path}
            echo
            echo
        else
            shift
            shift
            bash ${toolkit_path} $@
            exit 0
        fi
    } || {
        if [[ "${toolkit_name}" = "package" ]]; then
            shift
            shift
            bash platform/package-tools.sh  $@
        else
            echo "脚本 ${toolkit} 不存在，退出！"
            fun_print_toolkit_list
            exit 1
        fi
    }
}

function fun_sypctl_backup_file_caller() {
    if [[ "${2}" = "help" ]]; then
        fun_print_sypctl_backup_file_help
        exit 1
    fi

    support_commands=(list render execute guard)
    if [[ "${support_commands[@]}" =~ "$2" ]]; then
        SYPCTL_HOME=${SYPCTL_HOME} RAKE_ROOT_PATH=${SYPCTL_HOME}/agent ruby platform/ruby/backup-file-tools.rb "--$2" "${3:-all}"
    else
        echo "Error - unknown command: $2, support: ${support_commands[@]}"
    fi
}

function fun_sypctl_backup_mysql_caller() {
    if [[ "${2}" = "help" ]]; then
        fun_print_sypctl_backup_mysql_help
        exit 1
    fi

    support_commands=(help list state view check execute guard killer)
    if [[ "${2}" = "execute" ||  "${2}" = "guard" ]]; then
        process_state="abort"
        pid=
        pid_path=tmp/backup-mysql-ruby.pid
        log_path=logs/backup-mysql-nohup.log
        if [[ -f "${pid_path}" ]]; then
            pid=$(cat ${pid_path})
            ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            test $? -eq 0 && process_state="running"
        fi

        if [[ "${process_state}" = "running" ]]; then
            echo "${timestamp2} - backup process running(${pid})"
        else
            [[ $@ =~ "scope=hour" ]] && scope=hour || scope=day
            nohup ruby platform/ruby/backup-mysql-tools.rb "--$2" --home=${SYPCTL_HOME} --scope=${scope} >> ${log_path} 2>&1 &
            echo "--scope=${scope}"
            echo "--home=${SYPCTL_HOME}"
            echo "--timestamp=${timestamp2}"
            echo
            sleep 3
            sypctl backup:mysql state
            echo
            echo "command list:"
            echo "\$ sypctl backup:mysql state"
            echo "\$ sypctl backup:mysql view"
        fi
    elif [[ "${support_commands[@]}" =~ "$2" ]]; then
        ruby platform/ruby/backup-mysql-tools.rb "--$2" --home="${SYPCTL_HOME}"
    else
        echo "Error - 未知参数: $2, 仅支持: ${support_commands[@]}"
    fi
}

col1_width=${custom_col1_width:-36}
col2_width=${custom_col2_width:-42}
header_col1_width=$[$col1_width+$col2_width-1]
two_cols_table_divider=------------------------------
two_cols_table_divider=$two_cols_table_divider$two_cols_table_divider
two_cols_table_header="+%-${col1_width}.${col1_width}s+%-${col2_width}.${col2_width}s+\n"
two_cols_table_format="| %-$[$col1_width-2]s | %-$[$col2_width-2]s |\n"

function fun_print_table_header() {
    local header_text="${1}"
    
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
    printf "| %-${header_col1_width}s |\n" "${header_text}"
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
    printf "$two_cols_table_format" "$2" "$3"
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
}

function fun_print_table_footer() {
    local footer_text="$(uname -s) | ${1-Timestamp: $(date +'%Y-%m-%d %H:%M:%S')}"

    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
    printf "| %-${header_col1_width}s |\n" "${footer_text}"
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
}

function fun_left_34() {
    echo ${1:0:34}
}

function fun_right_34() {
    str="$1"
    length=${#str}
    left_pos=0
    if [[ ${length} -gt 34 ]]; then
        left_pos=$(expr $length - 34)
    fi
    echo ${str:${left_pos}:${length}}
}

function fun_print_two_cols_row() {
    one=$(fun_left_34 "$1")
    two=$(fun_right_34 "$2")
    printf "$two_cols_table_format" "${one}" "${two}"
}


function fun_prompt_command_already_installed() {
    command_name=$1
    version_lines=${2:-2}

    test -z "${command_name}" && {
        echo "warning: fun_prompt_command_already_installed need pass command name as paramters!"
        return 2
    }

    echo >&2 "${command_name} already installed:"
    echo
    echo "$ which ${command_name}"
    which ${command_name}
    echo "$ ${command_name} -v"
    ${command_name} -v | grep -v ^$ | head -n ${version_lines}

    return 0
}

function fun_prompt_java_already_installed() {
    expect_version=1.8.0
    origin_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    current_version=${origin_version%_*}
    [[ "$1" = "table" ]] && printf "$two_cols_table_format" "java" "${origin_version:0:40}" || java -version

    if [[ "${current_version}" != "${expect_version}" ]]; then
        echo 
        echo "current jdk version: ${current_version}"
        echo " expect jdk version: ${expect_version}"
        echo "run the command to force install expect jdk:"
        echo
        echo "$ sypctl toolkit jdk jdk:install:force"
        echo
    fi

    return 0
}

function fun_prompt_javac_already_installed() {
    version=$(javac -version 2>&1 | awk '{ print $2 }')
    [[ "$1" = "table" ]] && printf "$two_cols_table_format" "javac" "${version:0:40}" || javac -version
    return 0
}

function fun_prompt_nginx_already_installed() {
    if [[ "$1" = "table" ]]; then
        version=$(nginx -V 2>&1 | awk '/version/ { print $3 }')
        printf "$two_cols_table_format" "nginx" "${version:0:40}"
    else
        nginx -V
    fi
    return 0
}

function fun_prompt_redis_already_installed() {
    if [[ "$1" = "table" ]]; then
        version=$(redis-cli --version | awk '{ print $2 }')
        printf "$two_cols_table_format" "redis-cli" "${version:0:40}"
    else
        redis-cli --version
        redis-server --version
    fi
    return 0
}

function fun_prompt_vncserver_already_installed() {
    if [[ "$1" = "table" ]]; then
        printf "$two_cols_table_format" "vncserver" "$(which vncserver)"
    else
        echo "already installed vncserver!"
        rwhich vncserver
    fi
    return 0
}

