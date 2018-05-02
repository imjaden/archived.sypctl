#!/usr/bin/env bash

current_path=$(pwd)
test -f .env-files && source .env-files
test -f ~/.bash_profile && source ~/.bash_profile
cd ${current_path}

function title() { printf "\n%s\n\n", "$1"; }
function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
function fun_printf_timestamp() { printf "\n Timestamp: $(date +'%Y-%m-%d %H:%M:%S')\n"; }

function fun_install_lsb_release() {
    command -v lsb_release > /dev/null || {
        command -v yum > /dev/null && yum install -y redhat-lsb
        command -v apt-get > /dev/null && apt-get install -y lsb-release
        # command -v brew > /dev/null && brew install -y lsb-release
    }

    command -v lsb_release > /dev/null || {
        title "ERROR: The script is incompatible with the system!" 
        cat /etc/issue
        exit 1
    }
}

supported_os_platforms=(CentOS6 CentOS7 Ubuntu16)
function fun_basic_check_operate_system() {
    fun_install_lsb_release

    system=$(lsb_release -i | awk '{ print $3 }')
    version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
    if [[ "${supported_os_platforms[@]}" =~ "${system}${version}" ]]; then
        return 0
    else
        lsb_release -a

        return 1
    fi
}

fun_basic_check_operate_system

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
        echo "warning: fun_prompt_command_already_installed need pass command name as paramters!"
        return 2
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

function check_install_defenders_include() {
    test -f .install-defender || fun_user_expect_to_install_package_guides
    if [[ $(grep "$1" .install-defender | wc -l) -eq 0 ]]; then
       return 404
    else
       return 0
    fi
}

function fun_user_expect_to_install_package_guides() {
    true > .install-defender
    supported_packages=(Nginx JDK Redis Zookeeper VNC Tomcat ZipRaR Report SaaSImage SaaSBackup SYPSuperAdmin SYPAdmin SYPAPI SYPAPIService)
    for package in ${supported_packages[@]}; do
        read -p "Do you agree with the install ${package}? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            echo "${package}"
            echo ${package} >> .install-defender
        fi
    done
}

begin_placeholder=">>>>>>>>>>"
finished_placeholder="<<<<<<<<<<"

status_divider===============================
status_divider=$status_divider$status_divider
status_titles=(Service Type PID Comment)
status_header="\n %-15s %10s %-10s %-21s\n"
status_format=" %-15s %10s %-10s %-21s\n"
status_width=50
