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

source platform/Linux/common.sh

zk_home="${1:-$ZK_HOME}"
cmd_type="${2:-start}"
option="${3:-use-header}"

zookeeper_package=packages/zookeeper-3.4.12.tar.gz
zookeeper_hash=f43cca610c2e041c71ec7687cddbd0c3
zookeeper_version=zookeeper-3.4.12

case "${cmd_type}" in
    check)
        logger "TODO"
    ;; 
    install)
        if [[ -d ${zk_home} ]]; then
            printf "$two_cols_table_format" "Zookeeper" "Deployed"
            exit 2
        fi

        rm -fr ~/tools/${zookeeper_version} 
        test -d ~/tools || mkdir -p ~/tools
        if [[ ! -f ${zookeeper_package} ]]; then
            printf "$two_cols_table_format" "Zookeeper Package" "Not Found"
            printf "$two_cols_table_format" "Zookeeper package" "Downloading..."

            package_name="$(basename $zookeeper_package)"
            if [[ -f ${zookeeper_package} ]]; then  
                # @过期算法
                # tar jtvf packages/${package_name} > /dev/null 2>&1
                # if [[ $? -gt 0 ]]; then
                #     rm -f packages/${package_name}
                # fi
                #
                # @手工校正文件哈希
                current_hash=todo
                command -v md5 > /dev/null && current_hash=$(md5 -q ${zookeeper_package})
                command -v md5sum > /dev/null && current_hash=$(md5sum ${zookeeper_package} | cut -d ' ' -f 1)
                test "${zookeeper_hash}" != "${current_hash}" && rm -f ${zookeeper_package}
            fi

            if [[ ! -f ${zookeeper_package} ]]; then
                wget -q -P packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                printf "$two_cols_table_format" "Zookeeper package" "Downloaded"
            fi
        fi
        tar -xzvf ${zookeeper_package} -C ~/tools

        cp -r ~/tools/${zookeeper_version} ${zk_home}
        cp config/zoo.cfg ${zk_home}/conf
        mkdir -p /usr/local/src/zookeeper/{data,log}

        printf "$two_cols_table_format" "Zookeeper" "Deployed Successfully"
    ;;
    log)
        cd ${zk_home}
        echo "already enter zookeeper installed dir, do yourself!"
    ;;
    start|startup)
        test -f ~/.bash_profile && source ~/.bash_profile

        printf "$two_cols_table_format" "Zookeeper" "Starting..."
        bash ${zk_home}/bin/zkServer.sh start
        printf "$two_cols_table_format" "Zookeeper" "Started"
    ;;
    stop)
        test -f ~/.bash_profile && source ~/.bash_profile

        printf "$two_cols_table_format" "zookeeper" "Stroping..."
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
        printf "$two_cols_table_format" "Zookeeper" "Process Not Found"
        else
            printf "$two_cols_table_format" "Zookeeper" "${pids}"
            bash ${zk_home}/bin/zkServer.sh stop

            sleep 1s

            pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools.sh' | awk '{print $2}' | xargs)
            if [ -n "${pids}" ]; then
                kill -9 ${pids}
                printf "$two_cols_table_format" "Zookeeper" "KILL ${pids}"
            fi
        fi
        printf "$two_cols_table_format" "Zookeeper" "Stoped"
    ;;
    status|state)
        pids=$(ps aux | grep zookeeper | grep ${zk_home} | grep -v grep | grep -v 'zookeeper-tools' | awk '{print $2}' | xargs)

        if [ -n "${pids}" ]; then
            printf "$two_cols_table_format" "Zookeeper" "${pids}"
            exit 0
        else
            printf "$two_cols_table_format" "Zookeeper" "-"
            exit 1
        fi
    ;;
    monitor)
        bash $0 status ${zk_home} ${option}
        if [ $? -gt 0 ]; then
            printf "$two_cols_table_format" "Zookeeper" "Process Not Found"
            printf "$two_cols_table_format" "Zookeeper" "Starting..."
            bash $0 startup ${zk_home}
        fi
    ;;
    restart|restartup)
        bash $0 stop ${zk_home}
        bash $0 start ${zk_home}
    ;;
    help)
        echo "Zookeeper 管理:"
        echo "sypctl toolkit zookeeper help"
        echo "sypctl toolkit zookeeper check"
        echo "sypctl toolkit zookeeper install"
        echo "sypctl toolkit zookeeper start"
        echo "sypctl toolkit zookeeper status"
        echo "sypctl toolkit zookeeper stop"
        echo "sypctl toolkit zookeeper restart"
        echo "sypctl toolkit zookeeper monitor"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit zookeeper help
    ;;
esac