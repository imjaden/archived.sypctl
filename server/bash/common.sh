#!/usr/bin/env bash

current_path=$(pwd)
test -f .env-files && while read filepath; do
    test -f "${filepath}" && source "${filepath}"
done < .env-files
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

    # command -v lsb_release > /dev/null || {
    #     title "ERROR: The script is incompatible with the system!" 
    #     cat /etc/issue
    #     exit 1
    # }
}

supported_os_platforms=(RedHatEnterpriseServer6 RedHatEnterpriseServer7 CentOS6 CentOS7 Ubuntu16)
os_platform="UnknownOS"
function fun_basic_check_operate_system() {
    fun_install_lsb_release

    system=$(lsb_release -i | awk '{ print $3 }')
    version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
    if [[ "${supported_os_platforms[@]}" =~ "${system}${version}" ]]; then
        os_platform="${system}${version}"
        return 0
    else
        lsb_release -a
        return 1
    fi
}

fun_basic_check_operate_system

function fun_deploy_file_folder() {
    folder_path="$1"
    test -d ${folder_path} && printf "$two_cols_table_format" "$1" "Deployed" || {
        mkdir -p ${folder_path}
        printf "$two_cols_table_format" "$1" "Deployed Successfully"
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

    return 0
}

function fun_prompt_java_already_installed() {
    version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    printf "$two_cols_table_format" "java" "${version:0:40}"

    return 0
}

function fun_prompt_nginx_already_installed() {
    version=$(nginx -V 2>&1 | awk '/version/ { print $3 }')
    printf "$two_cols_table_format" "nginx" "${version:0:40}"

    return 0
}

function fun_prompt_redis_already_installed() {
    version=$(redis-cli --version)
    printf "$two_cols_table_format" "redis-cli" "${version:0:40}"

    return 0
}

function fun_prompt_vncserver_already_installed() {
    printf "$two_cols_table_format" "vncserver" "$(which vncserver)"

    return 0
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
    supported_packages=(Nginx JDK Redis Zookeeper VNC Report SaaSImage SaaSBackup SYPSuperAdmin SYPAdmin SYPAPI)
    for package in ${supported_packages[@]}; do
        read -p "Do you agree with the install ${package}? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            echo "${package}"
            echo ${package} >> .install-defender
        fi
    done
}

col1_width=${custom_col1_width:-36}
col2_width=${custom_col2_width:-42}
header_col1_width=$[$col1_width*2]
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
    local footer_text="${os_platform} | ${1-Timestamp: $(date +'%Y-%m-%d %H:%M:%S')}"

    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
    printf "| %-${header_col1_width}s |\n" "${footer_text}"
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
}