#!/usr/bin/env bash

source platform/common.sh

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

function fun_sypctl_check_dependent_packages() {
    command -v yum > /dev/null && {
        declare -a packages
        packages[0]=git
        packages[1]=tree
        packages[2]=wget
        packages[3]=make
        packages[4]=rdate
        packages[5]=dos2unix
        packages[6]=net-tools
        packages[7]=bzip2
        packages[8]=gcc
        packages[9]=gcc-c++
        packages[10]=automake
        packages[11]=autoconf
        packages[12]=libtool
        packages[13]=openssl
        packages[14]=vim-enhanced
        packages[15]=zlib-devel
        packages[16]=mysql-devel
        packages[17]=openssl-devel
        packages[18]=readline-devel
        packages[19]=iptables-services
        packages[20]=libxslt-devel.x86_64
        packages[21]=libxml2-devel.x86_64
        packages[22]=yum-plugin-downloadonly
        sudo yum install -y ${packages[@]}
    }

    command -v apt-get > /dev/null && {
        packages=(git rdate git-core git-doc lsb-release curl libreadline-dev libcurl4-gnutls-dev libssl-dev libexpat1-dev gettext libz-dev tree language-pack-zh-hant language-pack-zh-hans)
        for package in ${packages[@]}; do
          command -v ${package} > /dev/null || {
              printf "installing ${package}..."
              sudo apt-get build-dep -y ${package} > /dev/null 2>&1
              sudo apt-get install -y ${package} > /dev/null 2>&1
              printf "$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')\n"
          }
        done
    }
}

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

function fun_sypctl_clean() {
    crontab_conf="crontab-${timestamp}.conf"
    crontab -l > tmp/${crontab_conf}
    if [[ $(grep "# Begin sypctl" tmp/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' tmp/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' tmp/${crontab_conf} | tail -n 1)
        sed -i "${begin_line_num},${end_line_num}d" tmp/${crontab_conf}
    fi
    crontab tmp/${crontab_conf}

    rc_local_filepath=/etc/rc.d/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.local
    test -f ${rc_local_filepath} && {
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            sudo sed -i "${begin_line_num},${end_line_num}d" ${rc_local_filepath}
        fi
    }
    sudo chmod +x ${rc_local_filepath}

    fun_print_crontab_and_rclocal
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

function fun_user_expect_to_install_package_guides() {
    supported_packages=(Nginx Redis Zookeeper VNC ActiveMQ Report SYPSuperAdmin SYPAdmin SYPAPI)

    test -f .install-defender && while read package; do
        echo "已安装: ${package}"
    done < .install-defender
    echo ""
    for package in ${supported_packages[@]}; do
        if [[ $(grep "${package}" .install-defender | wc -l) -eq 0 ]]; then
            read -p "是否安装 ${package}? y/n: " user_input
            if [[ "${user_input}" = 'y' ]]; then
                echo ${package} >> .install-defender
            fi
        fi
    done

    if [[ ! -f agent/.config/local-server ]]; then
        read -p "是否启动代理端服务? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            echo ${timestamp} > agent/.config/local-server
        fi
    fi
}

function check_install_defenders_include() {
    test -f .install-defender || touch .install-defender
    if [[ $(grep "$1" .install-defender | wc -l) -eq 0 ]]; then
       return 404
    else
       return 0
    fi
}

function fun_sypctl_deploy() {
    mkdir -p logs
    bash platform/package-tools.sh state

    fun_user_expect_to_install_package_guides

    fun_print_table_header "Components State" "Component" "DeployedState"

    test -f .env-files && printf "$two_cols_table_format" ".env-files" "Deployed" || {
        cp config/saasrc .env-files
        printf "$two_cols_table_format" ".env-files" "Deployed Successfully"
    }

    check_install_defenders_include "Report" && {
        fun_deploy_file_folder /usr/local/src/report
        test -f .tutorial-conf.sh || {
            echo "var_shortcut='S'" > .tutorial-conf.sh
            echo "var_slogan='生意+ PaaS 服务引导页'" >> .tutorial-conf.sh
        }
        source .tutorial-conf.sh
        cp config/index@report.html syp-saas-tutorial.html
        sed -i "s/VAR_SHORTCUT/${var_shortcut}/g" syp-saas-tutorial.html
        sed -i "s/VAR_SLOGAN/${var_slogan}/g" syp-saas-tutorial.html
        test -f /usr/local/src/report/index.html || {
            cp syp-saas-tutorial.html /usr/local/src/report/index.html
        }
        mkdir -p /usr/local/src/www/
        mv syp-saas-tutorial.html /usr/local/src/www/syp-saas-tutorial.html
    }

    # check_install_defenders_include "ZipRaR" && {
    #     bash platform/Linux/archive-tools.sh check
    # }

    check_install_defenders_include "JDK" && {
        bash platform/Linux/jdk-tools.sh jdk:install
        bash platform/Linux/jdk-tools.sh javac:install
    }

    check_install_defenders_include "SYPAPI" && {
        root_path=/usr/local/src/tomcatAPI
        bash platform/Linux/tomcat-tools.sh install ${root_path} 8081
        # jar_path=/usr/local/src/providerAPI/api-service.jar
        # bash platform/Linux/jar-service-tools.sh install ${jar_path}
    }

    check_install_defenders_include "SYPSuperAdmin" && {
        root_path=/usr/local/src/tomcatSuperAdmin
        bash platform/Linux/tomcat-tools.sh install ${root_path} 8082
    }

    check_install_defenders_include "SYPAdmin" && {
        root_path=/usr/local/src/tomcatAdmin
        bash platform/Linux/tomcat-tools.sh install ${root_path} 8083
    }

    check_install_defenders_include "ActiveMQ" && {
        root_path=/usr/local/src/activeMQ
        bash platform/Linux/activemq-tools.sh install ${root_path}
    }

    check_install_defenders_include "Zookeeper" && {
        bash platform/Linux/zookeeper-tools.sh /usr/local/src/zookeeper install
    }

    check_install_defenders_include "Redis" && {
        bash platform/Linux/redis-tools.sh install
    }
    fun_print_table_footer
}

function fun_sypctl_deployed() {
    custom_col1_width=22
    custom_col2_width=32
    source platform/Linux/common.sh

    fun_print_table_header "Deployed State" "Component" "Version"
    dependency_commands=(git rbenv ruby gem bundle)
    for cmd in ${dependency_commands[@]}; do
        version=$(${cmd} --version)
        printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
    done
    fun_prompt_java_already_installed "table"

    test -f .install-defender && while read line; do
        printf "$two_cols_table_format" "Component" "$line"
    done < .install-defender

    fun_print_table_footer
}

function fun_sypctl_free_memory() {  
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

function fun_sypctl_disable_firewalld() {
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

    title "rc.local configuration:"
    rc_local_filepath=/etc/rc.d/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.local
    test -f ${rc_local_filepath} && {
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            pos=$(expr $end_line_num - $begin_line_num + 1)
            title "\$ cat ${rc_local_filepath} | head -n ${end_line_num} | tail -n ${pos}"
            cat ${rc_local_filepath} | head -n ${end_line_num} | tail -n ${pos}
        fi

        sudo chmod +x ${rc_local_filepath}
    } || {
        title "cannot found rc.local in below path:"
        echo "/etc/rc.local"
        echo "/etc/rc.d/rc.local"
    }
}

function fun_update_crontab_jobs() {
    test -d tmp || sudo mkdir tmp
    crontab_conf="crontab-${timestamp}.conf"

    crontab -l > tmp/${crontab_conf}

    if [[ $(grep "# Begin sypctl" tmp/${crontab_conf} | wc -l) -gt 0 ]]; then
        begin_line_num=$(sed -n '/# Begin sypctl/=' tmp/${crontab_conf} | head -n 1)
        end_line_num=$(sed -n '/# End sypctl/=' tmp/${crontab_conf} | tail -n 1)
        sed -i "${begin_line_num},${end_line_num}d" tmp/${crontab_conf}
    fi

    echo "" >> tmp/${crontab_conf}
    echo "# Begin sypctl crontab jobs at: ${timestamp}" >> tmp/${crontab_conf}
    echo "*/5 * * * * /usr/local/bin/sypctl schedule:jobs" >> tmp/${crontab_conf}
    echo "# End sypctl crontab jobs at: ${timestamp}" >> tmp/${crontab_conf}

    crontab tmp/${crontab_conf}
    crontab -l
}

function fun_update_rc_local() {
    rc_local_filepath=/etc/rc.d/rc.local
    test -f ${rc_local_filepath} || rc_local_filepath=/etc/rc.local

    test -f ${rc_local_filepath} && {
        sudo chmod go+w ${rc_local_filepath}
        cp ${rc_local_filepath} ${rc_local_filepath}-bk${timestamp}

        # 清理连续的空行，仅留最一个空行
        # 对比备份原文件，内容未变化则删除备份
        sed -i '/^$/{N;/\n$/D};' ${rc_local_filepath}
        diff ${rc_local_filepath} ${rc_local_filepath}-bk${timestamp} > /dev/null 2>&1
        [[ $? -eq 0 ]] && rm -f ${rc_local_filepath}-bk${timestamp}
        
        # 判断是否已配置，有则清除
        if [[ $(grep "# Begin sypctl services" ${rc_local_filepath} | wc -l) -gt 0 ]]; then
            begin_line_num=$(sed -n '/# Begin sypctl services/=' ${rc_local_filepath} | head -n 1)
            end_line_num=$(sed -n '/# End sypctl services/=' ${rc_local_filepath} | tail -n 1)
            sudo sed -i "${begin_line_num},${end_line_num}d" ${rc_local_filepath}
        fi

        sudo echo "" >> ${rc_local_filepath}
        sudo echo "# Begin sypctl services at: ${timestamp}" >> ${rc_local_filepath}
        sudo echo "test -n \"\${SYPCTL_HOME}\" || SYPCTL_HOME=/usr/local/src/sypctl" >> ${rc_local_filepath}
        sudo echo "mkdir -p \${SYPCTL_HOME}/logs" >> ${rc_local_filepath}
        sudo echo "su ${current_user} --login --shell /bin/bash --command \"/usr/local/bin/sypctl schedule:jobs\" > \${SYPCTL_HOME}/logs/startup1.log 2>&1" >> ${rc_local_filepath}
        sudo echo "su ${current_user} --login --shell /bin/bash --command \"/usr/local/bin/sypctl schedule:update\" > \${SYPCTL_HOME}/logs/startup2.log 2>&1" >> ${rc_local_filepath}
        sudo echo "# End sypctl services at: ${timestamp}" >> ${rc_local_filepath}

        sudo chmod +x ${rc_local_filepath}
    } || {
        title "cannot found rc.local in below path:"
        echo "/etc/rc.local"
        echo "/etc/rc.d/rc.local"
    }
}

function fun_app_caller() {
    mkdir -p agent/db/jobs
    case "$1" in
        app:config)
            fun_execute_bundle_rake_without_logger bundle exec rake app:config "key=$2" "value=$3" "uuid=$4"
        ;;
        *)
            fun_print_app_command_help
        ;;
    esac
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
