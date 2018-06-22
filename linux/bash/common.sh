#!/usr/bin/env bash

VERSION='0.0.68'
current_path=$(pwd)
current_user=$(whoami)
timestamp=$(date +'%Y%m%d%H%M%S')

test -n "${SYPCTL_HOME}" || SYPCTL_HOME=/usr/local/src/sypctl
test -f .env-files && while read filepath; do
    test -f "${filepath}" && source "${filepath}"
done < .env-files
test -f ~/.bash_profile && source ~/.bash_profile
cd ${current_path}

function title() { printf "\n%s\n\n" "$1"; }
function logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
function fun_printf_timestamp() { printf "\n Timestamp: $(date +'%Y-%m-%d %H:%M:%S')\n"; }

function fun_install() {
    command -v yum > /dev/null && {
        title "\$ sudo yum install -y $1"
        sudo yum install -y "$1"
    }
    command -v apt-get > /dev/null && {
        title "\$ sudo apt-get install -y $1"
        sudo apt-get install -y "$1"
    } 
}

command -v lsb_release > /dev/null || fun_install redhat-lsb

os_type="UnKnownOSType"
os_version="UnKnownOSVersion"
os_platform="UnknownOS"
supported_os_platforms=(RedHatEnterpriseServer6 RedHatEnterpriseServer7 CentOS6 CentOS7 Ubuntu16)
function fun_basic_check_operate_system() {
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
    echo "代理操作（可选）："
    echo "sypctl agent:init help"
    echo "sypctl agent:init uuid <服务器端分配的 UUID>"
    echo "sypctl agent:init human_name <业务名称>"
    echo
    echo "sypctl agent:task guard     代理守护者，注册、提交功能"
    echo "sypctl agent:task info      查看注册信息"
    echo "sypctl agent:task log       查看提交日志"
    echo "sypctl agent:job:daemon     服务器端任务的监护者"
    echo
    echo "常规操作："
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
    echo "sypctl toolkit <SYPCTL 脚本名称> [参数]"

    echo "sypctl etl:import <数据表连接配置档>"
    echo "sypctl etl:status"
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

function fun_print_logo() {
    echo 
    echo '  mmmm m     m mmmmm    mmm mmmmmmm m'
    echo ' #"   " "m m"  #   "# m"   "   #    #'
    echo ' "#mmm   "#"   #mmm#" #        #    #'
    echo '     "#   #    #      #        #    #'
    echo ' "mmm#"   #    #       "mmm"   #    #mmmmm'
    echo
}

function fun_upgrade() {
    old_version=$(sypctl version)
    git_current_branch=$(git rev-parse --abbrev-ref HEAD)
    title "\$ git pull origin ${git_current_branch}"
    git reset --hard HEAD
    git pull origin ${git_current_branch}

    if [[ "$(whoami)" != "root" ]]; then
        sudo chmod -R go+w ${SYPCTL_HOME}
        sudo chown -R ${current_user}:${current_user} ${SYPCTL_HOME}
    fi

    sypctl crontab > /dev/null 2>&1
    sypctl rc.local > /dev/null 2>&1
    sypctl linux:date check > /dev/null 2>&1

    if [[ "${old_version}" = "$(sypctl version)" ]]; then
        fun_print_logo
        title "current version ${old_version} already is latest version!"
        exit 0
    fi

    title "\$ cd agent && bundle install"
    cd agent
    mkdir -p {db,logs,tmp,jobs,monitor/{index,pages}}
    test -f device-uuid && mv device-uuid init-uuid # 旧 device uuid 作为初始化 uuid, 以避免 devuce uuid 生成策略调整；即支持 device uuid 更新
    rm -f db/agent.json # 升级后重新注册
    rm -f .bundle-done
    bundle install
    if [[ $? -eq 0 ]]; then
      echo "$ bundle install --local successfully"
      echo ${timestamp} > .bundle-done
    fi
    cd ..
    
    fun_print_logo
    title "upgrade from ${old_version} => $(sypctl version) successfully!"

    sypctl help
}

function fun_clean() {
    crontab_conf="crontab-${timestamp}.conf"
    crontab -l > ~/${crontab_conf}
    if [[ $(grep "# Begin sypctl" ~/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' ~/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' ~/${crontab_conf} | tail -n 1)
        sed -i "${begin_line_num},${end_line_num}d" ~/${crontab_conf}
    fi
    crontab ~/${crontab_conf}
    rm -f ~/${crontab_conf}

    rc_local_filepath=/etc/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.d/rc.local
    test -f ${rc_local_filepath} && {
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            sudo sed -i "${begin_line_num},${end_line_num}d" ${rc_local_filepath}
        fi
    }

    fun_print_crontab_and_rclocal
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

    test -d /data || mkdir -p /data
    check_install_defenders_include "SaaSImage" && {
        fun_deploy_file_folder /data/saas_images
    }

    check_install_defenders_include "SaaSBackup" && {
        fun_deploy_file_folder /data/saas_backups
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
        mkdir -p /usr/local/src/www/
        mv syp-saas-tutorial.html /usr/local/src/www/syp-saas-tutorial.html
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
    echo "$ sync (x3 times)"
    echo "$ echo 1 > /proc/sys/vm/drop_caches"
    echo

    sudo sync
    sudo sync
    sudo sync
    sudo echo 1 > /proc/sys/vm/drop_caches
    
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
    echo "$ $@ ..."

    cd agent
    test -f .bundle-done || {
        bundle install
        if [[ $? -eq 0 ]]; then
          echo "$ bundle install --local successfully"
          echo ${timestamp} > .bundle-done
        fi
    }

    [[ `uname -s` = "Darwin" ]] && {
        test -d logs || mkdir logs && { 
            log_count=$(ls logs/ | grep '.log' | wc -l)
            if [[ $log_count -gt 0 ]]; then
                archived_path=logs/archived/${timestamp}
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
    test -f .bundle-done || {
        bundle install
        if [[ $? -eq 0 ]]; then
          echo "$ bundle install --local successfully"
          echo ${timestamp} > .bundle-done
        fi
    }

    test -f local-sypctl-server && {
        bash tool.sh process:defender
    }

    $@
}

function fun_print_variable() {
    variable="$1"
    test -z $variable && {
        echo "please input variable name"
        return 1
    }
    eval "echo \${$variable}"
}

function fun_print_crontab_and_rclocal() {
    title "crontab configuration:"
    crontab_conf="crontab-${timestamp}.conf"
    crontab -l > ~/${crontab_conf}
    if [[ $(grep "# Begin sypctl" ~/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' ~/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' ~/${crontab_conf} | tail -n 1)
        pos=$(expr $end_line_num - $begin_line_num + 1)
        title "\$ crontab -l | head -n ${end_line_num} | tail -n ${pos}"
        crontab -l | head -n ${end_line_num} | tail -n ${pos}
    fi
    rm -f ~/${crontab_conf}

    title "rc.local configuration:"
    rc_local_filepath=/etc/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.d/rc.local
    test -f ${rc_local_filepath} && {
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            pos=$(expr $end_line_num - $begin_line_num + 1)
            title "\$ cat ${rc_local_filepath} | head -n ${end_line_num} | tail -n ${pos}"
            cat ${rc_local_filepath} | head -n ${end_line_num} | tail -n ${pos}
        fi
    } || {
        title "cannot found rc.local in below path:"
        echo "/etc/rc.local"
        echo "/etc/rc.d/rc.local"
    }
}

function fun_update_crontab_jobs() {
    test -d tmp || sudo mkdir tmp
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
    echo "*/5 * * * * sypctl agent:task guard" >> ~/${crontab_conf}
    echo "*/1 * * * * sypctl agent:job:daemon" >> ~/${crontab_conf}
    echo "0 0 * * * sypctl upgrade" >> ~/${crontab_conf}
    echo "0 0 * * * sypctl memory:free" >> ~/${crontab_conf}
    echo "# End sypctl crontab jobs at: ${timestamp}" >> ~/${crontab_conf}

    sudo cp ~/${crontab_conf} tmp/${crontab_conf}-updated
    crontab ~/${crontab_conf}
    crontab -l
    rm -f ~/${crontab_conf}
}

function fun_update_rc_local() {
    rc_local_filepath=/etc/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.d/rc.local

    test -f ${rc_local_filepath} && {
        sudo chmod go+w ${rc_local_filepath}
        
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            sudo sed -i "${begin_line_num},${end_line_num}d" ${rc_local_filepath}
        fi

        sudo echo "" >> ${rc_local_filepath}
        sudo echo "# Begin sypctl services at: ${timestamp}" >> ${rc_local_filepath}
        sudo echo "sudo -u ${current_user} sypctl crontab" >> ${rc_local_filepath}
        sudo echo "# End sypctl services at: ${timestamp}" >> ${rc_local_filepath}
    } || {
        title "cannot found rc.local in below path:"
        echo "/etc/rc.local"
        echo "/etc/rc.d/rc.local"
    }
}

function fun_print_init_agent_help() {
    echo "Usage: sypctl <command> [<args>]"
    echo 
    echo "sypctl agent:init help"
    echo "sypctl agent:init uuid <服务器端分配的 UUID>"
    echo "sypctl agent:init human_name <业务名称>"
    echo
    echo "sypctl agent:task guard     代理守护者，注册、提交功能"
    echo "sypctl agent:task info      查看注册信息"
    echo "sypctl agent:task log       查看提交日志"
    echo "sypctl agent:job:daemon     服务器端任务的监护者"
    echo 
    echo "Current version is $VERSION"
    echo "For full documentation, see: http://gitlab.ibi.ren/syp-apps/sypctl.git"
}

function fun_init_agent() {
    case "$1" in
        uuid)
            test -n "$2" && {
                echo "$2" > agent/init-uuid
                rm -f agent/db/agent.json
            } || sypctl agent:init help
        ;;
        human_name)
            test -n "$2" && {
                echo "$2" > agent/human-name
                rm -f agent/db/agent.json
                sypctl agent:task guard
                sypctl agent:task info
            } || sypctl agent:init help
        ;;
        help)
            fun_print_init_agent_help
        ;;
        *)
            fun_print_init_agent_help
        ;;
    esac
}

function fun_agent_job_daemon() {
    for filepath in $(ls agent/jobs/*.todo); do
        job_uuid=$(cat $filepath)
        mv ${filepath} ${filepath}-running
        bash agent/jobs/sypctl-job-${job_uuid}.sh > agent/jobs/sypctl-job-${job_uuid}.sh-output 2>&1 
        sypctl bundle exec rake agent:job uuid=${job_uuid} >> agent/jobs/sypctl-job-${job_uuid}.sh-output 2>&1 
        rm -f ${filepath}-running
    done
}

function fun_print_toolkit_list() {
    echo "Error: 请输入 sypctl 系统脚本名称！"
    echo
    echo "Usage: sypctl tookit <脚本名称> [参数]"
    echo
    echo "脚本列表："
    for tookit in $(ls linux/bash/*-tools.sh); do
        tookit=${tookit##*/}
        tookit=${tookit%-*}
    echo "- ${tookit}"
    done
}

function fun_toolkit_caller() {
    test -z "$2" && {
        fun_print_toolkit_list
        exit
    }

    toolkit=linux/bash/$2-tools.sh
    test -f ${toolkit} && {
        bash linux/bash/$2-tools.sh "$3" "$4" "$5" "$6"
    } || {
        echo "toolkit: $2 不存在，退出！"
        fun_print_toolkit_list
        exit 1
    }
}

function fun_etl_caller() {
    mkdir -p etl/{db,logs,tmp}
    ruby etl/sqoop/msserver-import.rb "$2" "$3"
    exit $?
}

function fun_etl_status() {
    mkdir -p etl/{db,logs,tmp}
    ruby etl/sqoop/msserver-status.rb
    exit $?
}

function fun_etl_tiny_tds() {
    ruby etl/sqoop/msserver-tiny_tds.rb "$2" "$3"
    exit $?
}

function fun_agent_server_daemon() {
    cd agent
    test -f ~/.bash_profile && {
        readlink -f ~/.bash_profile > env-files
    }

    test -f env-files || touch env-files
    test -f app-port || echo 8086 > app-port

    bash tool.sh process:defender
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