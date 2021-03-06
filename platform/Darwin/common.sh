#!/usr/bin/env bash

source platform/common.sh

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
    echo "*/5 * * * * /usr/local/bin/sypctl schedule:jobs" >> tmp/${crontab_conf}
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

    sudo chmod -R 700 ~/.ssh
    sudo chmod 600 ~/.ssh/authorized_keys

    echo "\$ ls -lt ~/.ssh/"
    ls -lt ~/.ssh/
    echo "\$ cat ~/.ssh/id_rsa.pub"
    cat ~/.ssh/id_rsa.pub
}


