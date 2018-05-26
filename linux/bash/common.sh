#!/usr/bin/env bash

VERSION='0.0.19'

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

os_type="UnKnownOSType"
os_version="UnKnownOSVersion"
os_platform="UnknownOS"
supported_os_platforms=(RedHatEnterpriseServer6 RedHatEnterpriseServer7 CentOS6 CentOS7 Ubuntu16)
function fun_basic_check_operate_system() {
    fun_install_lsb_release

    os_type=$(lsb_release -i | awk '{ print $3 }')
    os_version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
    if [[ "${supported_os_platforms[@]}" =~ "${os_type}${os_version}" ]]; then
        os_platform="${os_type}${os_version}"
    else
        os_platform=$(uname -s)
        lsb_release -a
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
    supported_packages=(Nginx Redis Zookeeper VNC Report SaaSImage SaaSBackup SYPSuperAdmin SYPAdmin SYPAPI)
    for package in ${supported_packages[@]}; do
        read -p "Do you agree with the install ${package}? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            echo "${package}"
            echo ${package} >> .install-defender
        fi
    done
}

function fun_print_sypctl_help() {
    echo "Usage: sypctl <command> [<args>]"
    echo 
    echo "sypctl help         sypctl 支持的命令参数列表，及已部署服务的信息"
    echo "sypctl deploy       部署服务引导，并安装部署输入 \`y\` 确认的服务"
    echo "sypctl deployed     查看已部署服务"
    echo "sypctl env          部署基础环境依赖：JDK/Rbenv/Ruby"
    echo "sypctl upgrade      更新 sypctl 源码"
    echo 
    echo "sypctl monitor      已部署的服务进程状态，若未监测到进程则启动该服务"
    echo "sypctl start        启动已部署的服务进程"
    echo "sypctl status       已部署的服务进程状态"
    echo "sypctl restart      重启已部署的服务进程"
    echo "sypctl stop         关闭已部署的服务进程"
    echo 
    echo "sypctl apk <app-name> 打包生意+ 安卓APK;支持的应用如下："
    echo "                      - 生意+ shengyiplus"
    echo "                      - 睿商+ ruishangplus"
    echo "                      - 永辉 yh_android"
    echo "                      - 保臻 shenzhenpoly"
    echo "sypctl <app-name>     切换生意+ iOS 不同项目的静态资源；应用名称同上"
    echo 
    echo "Current version is $VERSION"
    echo "For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git"
}

function fun_upgrade() {
    old_version=$(sypctl version)
    git_current_branch=$(git rev-parse --abbrev-ref HEAD)
    sudo git pull origin ${git_current_branch}

    cd agent
    sudo rm -f .bundle-done
    sudo bundle install
    cd ..
    
    echo 
    echo '                               m    ""#'
    echo '  mmm   m   m  mmmm    mmm   mm#mm    #'
    echo ' #   "  "m m"  #" "#  #"  "    #      #'
    echo '  """m   #m#   #   #  #        #      #'
    echo ' "mmm"   "#    ##m#"  "#mm"    "mm    "mm'
    echo '         m"    #'
    echo '        ""     "'
    echo 
    echo "upgrade from ${old_version} => $(sypctl version) successfully!"
    echo

    sypctl crontab > /dev/null 2>&1
    sypctl help
}

function fun_generate_sshkey_when_not_exist() {
    test -d ~/.ssh || ssh-keygen  -t rsa -P '' -f ~/.ssh/id_rsa
    test -f ~/.ssh/authorized_keys || touch ~/.ssh/authorized_keys

    chmod -R 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys

    ls -l ~/.ssh/
    cat ~/.ssh/id_rsa.pub
}

function fun_deploy_service_guides() {
    mkdir -p ./logs
    bash linux/bash/packages-tools.sh state
    fun_print_table_header "Components State" "Component" "DeployedState"

    test -f .env-files && printf "$two_cols_table_format" ".env-files" "Deployed" || {
        cp linux/config/saasrc .env-files
        printf "$two_cols_table_format" ".env-files" "Deployed Successfully"
    }

    check_install_defenders_include "SaaSImage" && {
        fun_deploy_file_folder ~/www/saas_images
    }

    check_install_defenders_include "SaaSBackup" && {
        fun_deploy_file_folder ~/www/saas_backups
    }

    check_install_defenders_include "Report" && {
        fun_deploy_file_folder /usr/local/src/report
        test -f .tutorial-conf.sh || {
            echo "var_shortcut='S'" > .tutorial-conf.sh
            echo "var_slogan='生意+ SaaS 系统服务引导页'" >> .tutorial-conf.sh
        }
        source .tutorial-conf.sh
        cp linux/config/index@report.html syp-saas-tutorial.html
        sed -i "s/VAR_SHORTCUT/${var_shortcut}/g" syp-saas-tutorial.html
        sed -i "s/VAR_SLOGAN/${var_slogan}/g" syp-saas-tutorial.html
        test -f /usr/local/src/report/index.html || {
            cp syp-saas-tutorial.html /usr/local/src/report/index.html
        }
        mv syp-saas-tutorial.html ~/www/syp-saas-tutorial.html
    }

    # check_install_defenders_include "ZipRaR" && {
    #     bash linux/bash/archive-tools.sh check
    # }

    check_install_defenders_include "JDK" && {
        bash linux/bash/jdk-tools.sh install
    }

    check_install_defenders_include "SYPAPI" && {
        bash linux/bash/tomcat-tools.sh /usr/local/src/tomcatAPI        install 8081
        bash linux/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar install
    }

    check_install_defenders_include "SYPSuperAdmin" && {
        bash linux/bash/tomcat-tools.sh /usr/local/src/tomcatSuperAdmin install 8082
    }

    check_install_defenders_include "SYPAdmin" && {
        bash linux/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin      install 8083
    }

    check_install_defenders_include "Zookeeper" && {
        bash linux/bash/zookeeper-tools.sh /usr/local/src/zookeeper install
    }

    check_install_defenders_include "Redis" && {
        bash linux/bash/redis-tools.sh install
    }
    fun_print_table_footer
}

function fun_print_deployed_services() {
    custom_col1_width=22
    custom_col2_width=32
    source linux/bash/common.sh

    fun_print_table_header "Deployed State" "Component" "Version"
    dependency_commands=(git rbenv ruby gem bundle)
    for cmd in ${dependency_commands[@]}; do
        version=$(${cmd} --version)
        printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
    done
    fun_prompt_java_already_installed

    test -f .install-defender && while read line; do
        printf "$two_cols_table_format" "Component" "$line"
    done < .install-defender

    fun_print_table_footer
}

function fun_operator_service_process() {
    fun_print_table_header "Components Process State" "Component" "ProcessId"

    check_install_defenders_include "Redis" && {
        bash linux/bash/redis-tools.sh $1 "no-header"
    }

    check_install_defenders_include "Zookeeper" && {
        bash linux/bash/zookeeper-tools.sh /usr/local/src/zookeeper $1 "no-header"
    }

    check_install_defenders_include "SYPAPI" && {
        bash linux/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar $1 "no-header"
        bash linux/bash/tomcat-tools.sh      /usr/local/src/tomcatAPI        $1 "no-header"
    }

    check_install_defenders_include "SYPSuperAdmin" && {
        bash linux/bash/tomcat-tools.sh      /usr/local/src/tomcatSuperAdmin $1 "no-header"
    }

    check_install_defenders_include "SYPAdmin" && {
        bash linux/bash/tomcat-tools.sh      /usr/local/src/tomcatAdmin      $1 "no-header"
    }
    check_install_defenders_include "Nginx" && {
        bash linux/bash/nginx-tools.sh $1 "no-header"
    }

    fun_print_table_footer
}

function fun_free_memory() {  
    free -m
    echo
    echo "$ echo 1 > /proc/sys/vm/drop_caches"
    echo
    echo 1 > /proc/sys/vm/drop_caches
    free -m
}

function fun_disable_firewalld() {
    command -v systemctl > /dev/null 2>&1 && {
        systemctl stop firewalld.service
        systemctl disable firewalld.service
        systemctl stop iptables.service
        systemctl disable iptables.service
        chkconfig iptables off
        firewall-cmd --state
        systemctl status iptables

        return 0
    }

    command -v service > /dev/null 2>&1 && {
        service iptables stop
        service iptables status

        return 0
    }
}

function fun_execute_env_script() {
    echo "same as execute bash below:"
    echo
    echo "curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/env.sh | bash"
    echo 
    bash env.sh
}

function fun_execute_bundle_rake() {
    cd agent
    timestamp=$(date +'%Y%m%d%H%M%S')

    test -f .bundle-done || {
        bundle install
        if [[ $? -eq 0 ]]; then
          echo "$ bundle install --local successfully"
          echo ${timestamp} > .bundle-done
        fi
    }

    # test -d logs || mkdir logs && { 
    #     log_count=$(ls logs/ | grep '.log' | wc -l)
    #     if [[ $log_count -gt 0 ]]; then
    #         archived_path=logs/archived/${timestamp}
    #         mkdir -p ${archived_path}
    #         mv logs/*.log ${archived_path}/
    #     fi
    # }

    echo "$ $@"
    $@ >> logs/task_agent-${timestamp}.log 2>&1
}

function fun_print_variable() {
    variable="$1"
    test -z $variable && {
        echo "please input variable name"
        return 1
    }
    eval "echo \${$variable}"
}

function fun_update_crontab_jobs() {
    test -d tmp || sudo mkdir tmp
    timestamp=$(date +'%Y%m%d%H%M%S')
    crontab_conf="crontab-${timestamp}.conf"

    crontab -l > ~/${crontab_conf}
    sudo cp ~/${crontab_conf} tmp/${crontab_conf}

    if [[ $(grep "# Begin sypctl" ~/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' ~/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' ~/${crontab_conf} | tail -n 1)
        sed -i "${begin_line_num},${end_line_num}d" ~/${crontab_conf}
    fi

    echo "" >> ~/.${crontab_conf}
    echo "# Begin sypctl crontab jobs at: ${timestamp}" >> ~/${crontab_conf}
    echo "*/5 * * * * sypctl bundle exec rake agent:submitor" >> ~/${crontab_conf}
    echo "# End sypctl crontab jobs at: ${timestamp}" >> ~/${crontab_conf}

    sudo cp ~/${crontab_conf} tmp/${crontab_conf}-updated
    crontab ~/${crontab_conf}
    crontab -l
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
    local footer_text="${os_platform} | ${1-Timestamp: $(date +'%Y-%m-%d %H:%M:%S')}"

    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
    printf "| %-${header_col1_width}s |\n" "${footer_text}"
    printf "$two_cols_table_header" "$two_cols_table_divider" "$two_cols_table_divider"
}