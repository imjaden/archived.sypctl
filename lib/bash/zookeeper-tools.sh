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

case "${cmd_type}" in
    check)
        logger "TODO"
    ;; 
    install)
        if [[ -d ${zk_home} ]]; then
            echo "prompt: ${zk_home} has already deployed!"
            exit 2
        fi

        zk_package=packages/zookeeper-3.3.6.tar.gz
        zk_version=zookeeper-3.3.6

        rm -fr ~/tools/${zk_version} 
        test -d ~/tools || mkdir -p ~/tools
        if [[ ! -f ${zk_package} ]]; then
            echo "warning: zookeeper package not found -${zk_package}" 
            exit 2
        fi
        tar -xzvf ${zk_package} -C ~/tools

        cp -r ~/tools/${zk_version} ${zk_home}
        cp lib/config/zoo.cfg ${zk_home}/conf
        mkdir -p /usr/local/src/zookeeper/{data,log}

        echo "prompt: ${zk_home} deployed successfully!"
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
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
            logger "zookeeper(${zk_home}) process not found"
        else
            logger "zookeeper(${zk_home}) pids: ${pids}"
            bash ${zk_home}/bin/zkServer.sh stop

            sleep 1s

            pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
            if [ -n "${pids}" ]; then
                kill -9 ${pids}
                logger "kill zookeeper(${zk_home}) process: ${pids}"
            fi
        fi
        logger "${finished_placeholder} stop zookeeper process, finished ${finished_placeholder}"
    ;;
    status|state)
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools' | awk '{print $2}' | xargs)

        printf "${status_header}" ${status_titles[@]}
        printf "%${status_width}.${status_width}s\n" "${status_divider}"
        if [ -n "${pids}" ]; then
            printf "${status_format}" "zookeeper" "master" ${pids} "${zk_home}"
            exit 0
        else
            printf "${status_format}" "zookeeper" "master" "-" "${zk_home}"
            exit 1
        fi
    ;;
    monitor)
        bash $0 ${zk_home} status
        if [ $? -gt 0 ]; then
            logger "zookeeper(${zk_home}) process not found then start..."
            logger
            bash $0 ${zk_home} startup
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