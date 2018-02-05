#!/bin/bash
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

zk_home="${1:-$ZK_HOME}"
cmd_type="${2:-start}"

logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
begin_placeholder=">>>>>>>>>>"
finished_placeholder="<<<<<<<<<<"

case "${cmd_type}" in
    check)
        logger "TODO"
    ;; 
    install)
        if [[ -d ${zk_home} ]]; then
            echo "prompt: ${zk_home} has already deployed, then exit!"
            exit 2
        fi

        zk_package=packages/zookeeper-3.3.6.tar.gz
        zk_version=zookeeper-3.3.6

        if [[ ! -d ~/tools/${zk_version} ]]; then
            test -d ~/tools || mkdir -p ~/tools
            if [[ ! -f ${zk_package} ]]; then
                echo "warning: zookeeper package not found -${zk_package}" 
                exit 2
            fi
            
            tar -xzvf ${zk_package} -C ~/tools
        fi

        cp -r ~/tools/${zk_version} ${zk_home}
        cp lib/config/zoo.cfg ${zk_home}/conf
        mkdir -p /usr/local/src/zookeeper/{data,log}
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
            echo "warning: zookeeper package not found - ${zk_package}"
            exit 2
        fi

        if [[ -d ${zk_install_path}/zookeeper ]]; then
            echo "prompt: zookeeper has already deployed - ${zk_install_path}/zookeeper"
            exit 2
        fi

        tar -xzvf ${zk_package} -C ${zk_install_path}
        mv ${zk_install_path}/${zk_version} ${zk_install_path}/zookeeper
        mkdir -p /usr/local/src/zookeeper/{data,log}
        echo "${zk_install_path}/zookeeper"
    ;;
    start|startup)
        test -f ~/.bash_profile && source ~/.bash_profile

        logger "${begin_placeholder} start zookeeper process, begin ${begin_placeholder}"
        bash ${zk_home}/bin/zkServer.sh start
        logger "${finished_placeholder} start zookeeper process, finished ${finished_placeholder}"
    ;;
    stop)
        test -f ~/.bash_profile && source ~/.bash_profile

        logger "${begin_placeholder} stop zookeeper process, begin ${begin_placeholder}"
        zk_pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ ! -n "${zk_pids}" ]; then
            logger "zookeeper(${zk_home}) process not found"
        else
            logger "zookeeper(${zk_home}) process: ${zk_pids}"
            bash ${zk_home}/bin/zkServer.sh stop

            sleep 1s

            zk_pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
            if [ -n "${zk_pids}" ]; then
                kill -9 ${zk_pids}
                logger "kill zookeeper(${zk_home}) process: ${zk_pids}"
            fi
        fi
        logger "${finished_placeholder} stop zookeeper process, finished ${finished_placeholder}"
    ;;
    status|state)
        test -f ~/.bash_profile && source ~/.bash_profile

        zk_pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ -n "${zk_pids}" ]; then
            logger "zookeeper(${zk_home}) process: $zk_pids"
        else
            logger "zookeeper(${zk_home}) process not found"
        fi
    ;;
    monitor)
        test -f ~/.bash_profile && source ~/.bash_profile

        zk_pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ -n "${zk_pids}" ]; then
            logger "zookeeper(${zk_home}) process: $zk_pids"
        else
            logger "zookeeper(${zk_home}) process not found then start..."
            logger
            bash $0 ${zk_home} startup
            logger
            logger "check zookeeper process..."
            logger
            bash $0 ${zk_home} monitor
        fi
    ;;
    restart|restartup)
        bash $0 ${zk_home} stop 
        logger
        logger
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