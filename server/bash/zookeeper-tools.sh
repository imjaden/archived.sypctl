#!/usr/bin/env bash
#
########################################
#  
#  Zookeeper Process Manager
#
########################################
#
#
# 参数说明:(传参顺序必须一致)
#
# @zookeeper_home  zookeeper 部署路径, 默认 ZK_HOME
# @cmd_type  执行命令，默认 start，放在最后，方便动态追加自定义参数
#
# 完整示例：
#
# ```
# zk_home=/usr/local/src/zookeeper
# cmd_type=start
#
# bash # zookeeper-tools.sh ${zk_home} ${cmd_type}
# ```

source lib/bash/common.sh

zk_home="${1:-$ZK_HOME}"
cmd_type="${2:-start}"
option="${3:-use-header}"

case "${cmd_type}" in
    check)
        logger "TODO"
    ;; 
    install)
        if [[ -d ${zk_home} ]]; then
            printf "$two_cols_table_format" "zookeeper" "Deployed"
            exit 2
        fi

        zk_package=server/packages/zookeeper-3.3.6.tar.gz
        zk_version=zookeeper-3.3.6

        rm -fr ~/tools/${zk_version} 
        test -d ~/tools || mkdir -p ~/tools
        if [[ ! -f ${zk_package} ]]; then
            printf "$two_cols_table_format" "zookeeper" "ERROR: Package Not Found"
            exit 2
        fi
        tar -xzvf ${zk_package} -C ~/tools

        cp -r ~/tools/${zk_version} ${zk_home}
        cp lib/config/zoo.cfg ${zk_home}/conf
        mkdir -p /usr/local/src/zookeeper/{data,log}

        printf "$two_cols_table_format" "zookeeper" "Deployed Successfully"
    ;;
    log)
        cd ${zk_home}
        echo "already enter zookeeper installed dir, do yourself!"
    ;;
    install)
        zk_package="zookeeper-3.3.6.tar.gz"
        zk_install_path=/usr/local/src
        zk_version=zookeeper-3.3.6

        if [[ ! -f ${zk_package} ]]; then
            printf "$two_cols_table_format" "zookeeper" "Tar Package Not Found"
            exit 2
        fi

        if [[ -d ${zk_install_path}/zookeeper ]]; then
            printf "$two_cols_table_format" "zookeeper" "Deployed"
            exit 2
        fi

        tar -xzvf ${zk_package} -C ${zk_install_path}
        mv ${zk_install_path}/${zk_version} ${zk_install_path}/zookeeper
        mkdir -p /usr/local/src/zookeeper/{data,log}
    ;;
    start|startup)
        test -f ~/.bash_profile && source ~/.bash_profile

        printf "$two_cols_table_format" "zookeeper" "Starting..."
        bash ${zk_home}/bin/zkServer.sh start
        printf "$two_cols_table_format" "zookeeper" "Started"
    ;;
    stop)
        test -f ~/.bash_profile && source ~/.bash_profile

        printf "$two_cols_table_format" "zookeeper" "Stroping..."
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
        printf "$two_cols_table_format" "zookeeper" "Process Not Found"
        else
            printf "$two_cols_table_format" "zookeeper" "${pids}"
            bash ${zk_home}/bin/zkServer.sh stop

            sleep 1s

            pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
            if [ -n "${pids}" ]; then
                kill -9 ${pids}
                printf "$two_cols_table_format" "zookeeper" "KILL ${pids}"
            fi
        fi
        printf "$two_cols_table_format" "zookeeper" "Stoped"
    ;;
    status|state)
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools' | awk '{print $2}' | xargs)

        if [ -n "${pids}" ]; then
            printf "$two_cols_table_format" "zookeeper" "${pids}"
            exit 0
        else
            printf "$two_cols_table_format" "zookeeper" "-"
            exit 1
        fi
    ;;
    monitor)
        bash $0 ${zk_home} status ${option}
        if [ $? -gt 0 ]; then
            printf "$two_cols_table_format" "zookeeper" "Process Not Found"
            printf "$two_cols_table_format" "zookeeper" "Starting..."
            bash $0 ${zk_home} startup
        fi
    ;;
    restart|restartup)
        bash $0 ${zk_home} stop 
        bash $0 ${zk_home} start 
    ;;
    auto:generage:praams|agp)
        cat $0 | grep "|*)$" | grep -v echo | awk '{gsub(/ /,"")}1' | awk -F ')' '{print "logger \"    $0 "$1" zk_home\"" }'
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 zk_home start"
        logger "    $0 zk_home stop"
        logger "    $0 zk_home status|state"
        logger "    $0 zk_home monitor"
        logger "    $0 zk_home restart"
        logger "    $0 zk_home auto:generage:praams|agp"
    ;;
esac