#!/usr/bin/env bash

current_path=$(pwd)
test -f .saasrc && source .saasrc
test -f ~/.bash_profile && source ~/.bash_profile
cd ${current_path}

function fun_install_lsb_release() {
    command -v lsb_release > /dev/null || {
        command -v yum > /dev/null && yum install -y redhat-lsb
        command -v apt-get > /dev/null && apt-get install -y lsb-release
        # command -v brew > /dev/null && brew install -y lsb-release
    }
}
function fun_basic_check_operate_system() {
    fun_install_lsb_release
    command -v lsb_release > /dev/null || {
        title "error: unsupport operate system!" 
        exit 1
    }

    system=$(lsb_release -i | awk '{ print $3 }')
    version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
    is_support=1
    if [[ ${system} != "CentOS" ]]; then
        if [[ ${version} = "6" || ${version} = "7" ]]; then
            is_support=0
        fi
    fi
    if [[ ${is_support} -gt 0 ]]; then
        title "error: unsupport operate system!" 
    fi

    exit is_support
}
function title() {
    echo
    echo "$1"
    echo
}

fun_basic_check_operate_system

function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

function fun_deploy_file_folder() {
    folder_path="$1"
    test -d ${folder_path} && echo "${folder_path} already deployed!" || {
        mkdir -p ${folder_path}
        echo "${folder_path} deployed successfully"
    }
}

function fun_deploy_file_folder() {
    folder_path="$1"
    test -d ${folder_path} && echo "${folder_path} already deployed!" || {
        mkdir -p ${folder_path}
        echo "${folder_path} deployed successfully"
    }
}

function fun_prompt_command_already_installed() {
    command_name=$1
    version_lines=${2:-2}

    test -z "${command_name}" && {
        echo "warning: fun_prompt_command_already_installed need pass command name as paramters!";return 2
    }

    echo >&2 "${command_name} already installed:"
    echo
    echo "$ which ${command_name}"
    which ${command_name}
    echo "$ ${command_name} -v"
    ${command_name} -v | grep -v ^$ | head -n ${version_lines}

    exit 0
}

function fun_prompt_java_already_installed() {
    echo >&2 "java already installed!"
    echo
    echo "$ which java"
    which java
    echo
    echo "$ java -version"
    java -version

    exit 0
}

function fun_prompt_nginx_already_installed() {
    echo >&2 "nginx already installed:"
    echo
    echo "$ which nginx"
    which nginx
    echo
    echo "$ nginx -v"
    nginx -v
    echo
    echo "$ nginx -t"
    nginx -t

    exit 0
}

function fun_prompt_redis_already_installed() {
    echo >&2 "redis already installed:"
    echo
    echo "$ which redis-cli"
    which redis-cli
    echo
    echo "$ redis-cli --version"
    redis-cli --version

    exit 0
}

function fun_prompt_vncserver_already_installed() {
    echo >&2 "redis already installed:"
    echo
    echo "$ which vncserver"
    which vncserver

    exit 0
}

begin_placeholder=">>>>>>>>>>"
finished_placeholder="<<<<<<<<<<"

status_divider===============================
status_divider=$status_divider$status_divider
status_titles=(Service Type PID Comment)
status_header="\n %-15s %10s %-10s %-21s\n"
status_format=" %-15s %10s %-10s %-21s\n"
status_width=50

function fun_printf_timestamp() {
    printf "\n Timestamp: $(date +'%Y-%m-%d %H:%M:%S')\n"
}