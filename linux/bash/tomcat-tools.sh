#!/usr/bin/env bash
#
########################################
#  
#  Tomcat Process Manager(War)
#
########################################
#
# 建议在 ~/.bash_profile 中配置 TOMCAT_HOME 变量
#--------------------------------------------
#
# 参数说明:(传参顺序必须一致)
#
# @tomcat_home   tomcat 部署路径，默认为 TOMCAT_HOME
# @cmd_type      执行 tomcat 的命令，支持 shutdown/startup/restartup, 默认 startup
#
# 完整示例：
#
# ```
# tomcat_home="/usr/java_env/apache-tomcat-8.0.43"
# cmd_type="startup"
#
# bash tomcat-tools.sh "${tomcat_home}" "${cmd_type}"
# ```

source linux/bash/common.sh

tomcat_home="${1:-$TOMCAT_HOME}"
cmd_type="${2:-startup}"
option="${3:-use-header}"

case "${cmd_type}" in
    check)
        printf "$two_cols_table_format" "Tomcat:check" "TODO"
    ;; 
    install)
        if [[ -d ${tomcat_home} ]]; then
            printf "$two_cols_table_format" "${tomcat_home}" "Deployed"
            exit 2
        fi

        tomcat_package=linux/packages/apache-tomcat-8.5.24.tar.gz
        tomcat_version=apache-tomcat-8.5.24

        if [[ ! -d ~/tools/${tomcat_version} ]]; then
            test -d ~/tools || mkdir -p ~/tools
            if [[ ! -f ${tomcat_package} ]]; then
                printf "$two_cols_table_format" "Tomcat package" "Not Found"
                printf "$two_cols_table_format" "Tomcat package" "Downloading..."

                mkdir -p linux/packages
                package_name="$(basename $redis_package)"
                if [[ -f linux/packages/${package_name} ]]; then
                  tar jtvf packages/${package_name} > /dev/null 2>&1
                  if [[ $? -gt 0 ]]; then
                      rm -f linux/packages/${package_name}
                  fi
                fi

                if [[ ! -f linux/packages/${package_name} ]]; then
                    wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                    printf "$two_cols_table_format" "Tomcat package" "Downloaded"
                fi
            fi
            
            tar -xzvf ${tomcat_package} -C ~/tools
        fi

        tomcat_port="${3:-8081}"
        cp linux/config/setting-${tomcat_port}.xml ~/tools/${tomcat_version}/conf/server.xml
        cp -r ~/tools/${tomcat_version} ${tomcat_home}

        printf "$two_cols_table_format" "${tomcat_home}" "deployed successfully"
    ;;
    log)
        cd ${tomcat_home}
        tail -f logs/catalina.out
    ;;
    start|startup)
        printf "$two_cols_table_format" "${tomcat_home}" "Starting..."
        cat /dev/null > ${tomcat_home}/logs/catalina.out
        rm -rf ${tomcat_home}/work/* 

        sleep 1s

        bash ${tomcat_home}/bin/startup.sh > /dev/null 2>&1
        printf "$two_cols_table_format" "${tomcat_home}" "Started"

        bash $0 ${tomcat_home} status
    ;;
    stop)
        printf "$two_cols_table_format" "${tomcat_home}" "Stoping..."
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
            printf "$two_cols_table_format" "${tomcat_home}" "Pid Not Found"
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
        printf "$two_cols_table_format" "${tomcat_home}" "Stoped"
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
        bash $0 ${tomcat_home} status ${option}
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "${tomcat_home}" "Not Found"
            printf "$two_cols_table_format" "${tomcat_home}" "Starting..."
            bash $0 ${tomcat_home} startup
        fi
    ;;
    restart|restartup)
        bash $0 ${tomcat_home} stop
        bash $0 ${tomcat_home} startup
    ;;
    auto:generage:praams|agp)
        cat $0 | grep "|*)$" | grep -v echo | awk '{gsub(/ /,"")}1' | awk -F ')' '{print "logger \"    $0 "$1" tomcat_home\"" }'
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 tomcat_home install"
        logger "    $0 tomcat_home check"
        logger "    $0 tomcat_home stop"
        logger "    $0 tomcat_home status|state"
        logger "    $0 tomcat_home monitor"
        logger "    $0 tomcat_home restart"
        logger "    $0 tomcat_home auto:generage:praams|agp"
    ;;
esac