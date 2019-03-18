#!/usr/bin/env bash

source platform/common.sh

#
# sypctl 版本升级后的处理逻辑
#
function fun_sypctl_upgrade() {
    fun_sypctl_pre_upgrade || exit 1
    
    # # 升级 sypctl 源代码
    # old_version=$(sypctl version)
    # git_current_branch=$(git rev-parse --abbrev-ref HEAD)
    # git reset --hard HEAD  > /dev/null 2>&1
    # git pull origin ${git_current_branch} > /dev/null 2>&1
    ln -snf ${SYPCTL_HOME}/sypctl.sh /usr/local/bin/sypctl
    ln -snf ${SYPCTL_HOME}/bin/syps.sh /usr/local/bin/syps
    ln -snf ${SYPCTL_HOME}/bin/sypt.sh /usr/local/bin/sypt

    # # 分配源代码权限
    # if [[ "$(whoami)" != "root" ]]; then
    #     sudo chmod -R go+w ${SYPCTL_HOME}
    #     sudo chown -R ${current_user}:${current_user} ${SYPCTL_HOME}
    # fi

    sypctl check:dependent_packages

    # # 编译 sypctl 代理端服务
    # # bundle 操作必须执行，所 ruby 脚本依赖的包都维护在该 Gemfile 中
    # cd agent
    # mkdir -p {monitor/{index,pages},logs,tmp/pids,db,.config}
    # rm -f .config/bundle-done
    # bundle install > /dev/null 2>&1
    # test $? -eq 0 && echo ${timestamp} > .config/bundle-done
    # test -f .config/local-server && bash tool.sh restart
    # cd ..

    if [[ "${old_version}" = "$(sypctl version)" ]]; then
        fun_print_logo
        title "current version ${old_version} already is latest version!"
        exit 1
    fi

    # if [[ "${sypctl_mode}" = "server" ]]; then
    #     # 升级后重新提交主机信息
    #     test -f agent/db/agent.json && mv agent/db/agent.json agent/db/agent.json-${timestamp}

    #     # 升级生重新备份配置档
    #     test -f agent/db/file-backups/synced.hash && rm -f agent/db/file-backups/synced.hash
    #     test -f agent/db/file-backups/synced.json && mv agent/db/file-backups/synced.json agent/db/file-backups/synced.json-${timestamp}

    #     # 升级后重要实时同步的操作
    #     sypctl toolkit date check > /dev/null 2>&1
    #     sypctl memory:free > /dev/null 2>&1
    #     sypctl schedule:update > /dev/null 2>&1
    #     sypctl schedule:jobs > /dev/null 2>&1
    # fi

    title "upgrade from ${old_version} => $(sypctl version) successfully!"
    ruby platform/ruby/behavior.rb --old="${old_version}" --new="$(sypctl version)"

    sypctl help
}

function fun_sypctl_check_dependent_packages() {
    echo "TODO"
}

function fun_print_crontab_and_rclocal() {
    title "crontab configuration:"
    crontab_conf="crontab-${timestamp}.conf"
    crontab -l > tmp/${crontab_conf}
    if [[ $(grep "# Begin sypctl" tmp/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' tmp/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' tmp/${crontab_conf} | tail -n 1)
        pos=$(expr $end_line_num - $begin_line_num + 1)
        title "\$ crontab -l | head -n ${end_line_num} | tail -n ${pos}"
        crontab -l | head -n ${end_line_num} | tail -n ${pos}
    fi
}

function fun_sypctl_deploy() {
    echo "$(uname -s) 不支持 deploy 操作"
}

function fun_sypctl_deployed() {
    echo "$(uname -s) 不支持 deployed 操作"
}

function fun_update_rc_local() {
    echo "$(uname -s) 不支持 rc.local 操作"
}

function fun_sypctl_free_memory() {
    echo "$(uname -s) 不支持 free memory 操作"
}

function fun_sypctl_disable_firewalld() {
    echo "$(uname -s) 不支持 disabe firewalld 操作"
}

#
# 系统偏好设置 - 安全性与隐私 - 隐私 - 完全磁盘访问权限 - 添加应用程序: iterm
#
function fun_update_crontab_jobs() {
    mkdir -p tmp
    crontab_conf="crontab-${timestamp}.conf"

    crontab -l > tmp/${crontab_conf}
    if [[ $(grep "# Begin sypctl" tmp/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' tmp/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' tmp/${crontab_conf} | tail -n 1)
        sed -i "" "${begin_line_num},${end_line_num}d" tmp/${crontab_conf}
    fi

    echo "" >> tmp/${crontab_conf}
    echo "# Begin sypctl crontab jobs at: ${timestamp}" >> tmp/${crontab_conf}
    echo "*/5 * * * * sypctl schedule:jobs" >> tmp/${crontab_conf}
    echo "# End sypctl crontab jobs at: ${timestamp}" >> tmp/${crontab_conf}

    crontab tmp/${crontab_conf}
    crontab -l
}

function fun_sypctl_clean() {
    crontab_conf="crontab-${timestamp}.conf"
    crontab -l > tmp/${crontab_conf}
    if [[ $(grep "# Begin sypctl" tmp/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' tmp/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' tmp/${crontab_conf} | tail -n 1)
        sed -i "" "${begin_line_num},${end_line_num}d" tmp/${crontab_conf}
    fi

    crontab tmp/${crontab_conf}
}

function fun_sypctl_ssh_keygen() {
    test -d ~/.ssh || ssh-keygen  -t rsa -P '' # -f ~/.ssh/id_rsa
    test -f ~/.ssh/authorized_keys || touch ~/.ssh/authorized_keys

    chmod -R 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys

    ls -l ~/.ssh/
    cat ~/.ssh/id_rsa.pub
}

function fun_sypctl_service_caller() {
    if [[ "${2}" = "help" ]]; then
        fun_print_sypctl_service_help
        exit 1
    fi

    sudo mkdir -p /etc/sypctl/
    support_commands=(render list start stop status restart monitor edit guard)
    if [[ "$2" = "edit" ]]; then
        vim /etc/sypctl/services.json
    elif [[ "${support_commands[@]}" =~ "$2" ]]; then
        SYPCTL_HOME=${SYPCTL_HOME} RAKE_ROOT_PATH=${SYPCTL_HOME}/agent ruby platform/ruby/service-tools.rb "--$2" "${3:-all}"
    else
        echo "Error - unknown command: $2, support: ${support_commands[@]}"
    fi
}

