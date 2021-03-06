#!/usr/bin/env bash
#
########################################
#  
#  Tomcat Process Manager(War)
#
########################################
#
# 参数说明:(传参顺序必须一致)
#
# @tomcat_home   tomcat 部署路径，默认为 TOMCAT_HOME
# @cmd_type      执行 tomcat 的命令，支持 shutdown/startup/restartup, 默认 startup
#
# 完整示例：
#
# ```
# tomcat_home="/usr/local/src/tomcatAdmin"
# cmd_type="install"
#
# bash tomcat-tools.sh "${tomcat_home}" "${cmd_type}"
# ```

source platform/Linux/common.sh

cmd_type="${1:-startup}"
tomcat_home="${2:-$TOMCAT_HOME}"
option="${3:-use-header}"

case "${cmd_type}" in
    check)
        printf "$two_cols_table_format" "Tomcat:check" "TODO"
    ;; 
    install)
        if [[ -d ${tomcat_home} ]]; then
            printf "$two_cols_table_format" "${tomcat_home}" "deployed"
            exit 2
        fi

        tomcat_package=packages/apache-tomcat-8.5.24.tar.gz
        tomcat_hash=b21bf4f2293b2e4a33989a2d4f890d5a
        tomcat_version=apache-tomcat-8.5.24

        if [[ ! -d tmp/${tomcat_version} ]]; then
            if [[ ! -f ${tomcat_package} ]]; then
                printf "$two_cols_table_format" "Tomcat package" "not exist"
                printf "$two_cols_table_format" "Tomcat package" "downloading..."

                package_name="$(basename $tomcat_package)"
                if [[ -f ${tomcat_package} ]]; then    
                    # @过期算法
                    # tar jtvf packages/${package_name} > /dev/null 2>&1
                    # if [[ $? -gt 0 ]]; then
                    #     rm -f packages/${package_name}
                    # fi
                    #
                    # @手工校正文件哈希
                    current_hash=todo
                    command -v md5 > /dev/null && current_hash=$(md5 -q ${tomcat_package})
                    command -v md5sum > /dev/null && current_hash=$(md5sum ${tomcat_package} | cut -d ' ' -f 1)
                    test "${tomcat_hash}" != "${current_hash}" && rm -f ${tomcat_package}
                fi

                if [[ ! -f ${tomcat_package} ]]; then
                    wget -q -P packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                    printf "$two_cols_table_format" "Tomcat package" "downloaded"
                fi
            fi
            
            tar -xzvf ${tomcat_package} -C tmp
            rm -f tmp/${tomcat_version}/lib/.*.jar > /dev/null 2>&1
        fi

        tomcat_port="${3:-8081}"
        cp config/setting-${tomcat_port}.xml tmp/${tomcat_version}/conf/server.xml
        cp -r tmp/${tomcat_version} ${tomcat_home}

        printf "$two_cols_table_format" "${tomcat_home}" "deployed successfully"
    ;;
    log)
        cd ${tomcat_home}
        tail -f logs/catalina.out
    ;;
    start|startup)
        printf "$two_cols_table_format" "${tomcat_home}" "starting..."
        cat /dev/null > ${tomcat_home}/logs/catalina.out
        rm -rf ${tomcat_home}/work/* 
        rm -f ${tomcat_home}/lib/.*.jar > /dev/null 2>&1

        sleep 1s

        bash ${tomcat_home}/bin/startup.sh > /dev/null 2>&1
        printf "$two_cols_table_format" "${tomcat_home}" "started"

        bash $0 status ${tomcat_home}
    ;;
    stop)
        printf "$two_cols_table_format" "${tomcat_home}" "Stoping..."
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
            printf "$two_cols_table_format" "${tomcat_home}" "pid not found"
        else
            printf "$two_cols_table_format" "${tomcat_home}" "${pids}"
            bash ${tomcat_home}/bin/shutdown.sh

            sleep 1s

            pids=$(ps aux | grep tomcat | grep ${tomcat_home}| grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
            if [ -n "${pids}" ]; then
                printf "$two_cols_table_format" "${tomcat_home}" "KILL ${pids}"
                kill -9 ${pids}
            fi
        fi
        printf "$two_cols_table_format" "${tomcat_home}" "stoped"
    ;;
    status|state)
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)

        if [ -n "${pids}" ]; then
            printf "$two_cols_table_format" "${tomcat_home}" "${pids}"
            exit 0
        else
            printf "$two_cols_table_format" "${tomcat_home}" "-"
            exit 1
        fi
    ;;
    monitor)
        bash $0 status ${tomcat_home} ${option}
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "${tomcat_home}" "not found"
            printf "$two_cols_table_format" "${tomcat_home}" "starting..."
            bash $0 startup ${tomcat_home}
        fi
    ;;
    restart|restartup)
        bash $0 stop ${tomcat_home}
        bash $0 startup ${tomcat_home}
    ;;
    help)
        echo "Tomcat 管理:"
        echo "sypctl toolkit tomcat help"
        echo "sypctl toolkit tomcat check"
        echo "sypctl toolkit tomcat install"
        echo "sypctl toolkit tomcat start"
        echo "sypctl toolkit tomcat status"
        echo "sypctl toolkit tomcat restart"
        echo "sypctl toolkit tomcat monitor"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit tomcat help
    ;;
esac