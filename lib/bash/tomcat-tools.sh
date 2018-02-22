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

tomcat_home="${1:-$TOMCAT_HOME}"
cmd_type="${2:-startup}"

test -f ~/.bash_profile && source ~/.bash_profile

logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
begin_placeholder=">>>>>>>>>>"
finished_placeholder="<<<<<<<<<<"

case "${cmd_type}" in
    check)
        logger "TODO"
    ;; 
    install)
        if [[ -d ${tomcat_home} ]]; then
            echo "prompt: ${tomcat_home} has already deployed!"
            exit 2
        fi

        tomcat_package=packages/apache-tomcat-8.5.24.tar.gz
        tomcat_version=apache-tomcat-8.5.24

        if [[ ! -d ~/tools/${tomcat_version} ]]; then
            test -d ~/tools || mkdir -p ~/tools
            if [[ ! -f ${tomcat_package} ]]; then
                echo "warning: tomcat package not found -${tomcat_package}" 
                exit 2
            fi
            
            tar -xzvf ${tomcat_package} -C ~/tools
        fi

        tomcat_port="${3:-8081}"
        cp lib/config/setting-${tomcat_port}.xml ~/tools/${tomcat_version}/conf/server.xml
        cp -r ~/tools/${tomcat_version} ${tomcat_home}

        echo "prompt: ${tomcat_home} deployed with http port ${tomcat_port} successfully!"
    ;;
    log)
        cd ${tomcat_home}
        tail -f logs/catalina.out
    ;;
    start|startup)
        logger "${begin_placeholder} start tomcat process, start ${begin_placeholder}"
        cat /dev/null > ${tomcat_home}/logs/catalina.out
        rm -rf ${tomcat_home}/work/* 
        logger "clear catalina.out、remove tomcat/work, done"

        sleep 1s

        bash ${tomcat_home}/bin/startup.sh
        logger "${finished_placeholder} start tomcat process, finished ${finished_placeholder}"
    ;;
    stop)
        logger "${begin_placeholder} stop tomcat process, begin ${begin_placeholder}"
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
        if [ ! -n "${pids}" ]; then
            logger "tomcat(${tomcat_home}) process not found"
        else
            logger "tomcat(${tomcat_home}) process: ${pids}"
            bash ${tomcat_home}/bin/shutdown.sh

            sleep 1s

            pids=$(ps aux | grep tomcat | grep ${tomcat_home}| grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
            if [ -n "${pids}" ]; then
                logger "kill process(${tomcat_home}): ${pids}"
                kill -9 ${pids}
            fi
        fi
        logger "${finished_placeholder} stop tomcat process, finished ${finished_placeholder}"
    ;;
    status|state)
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            logger "tomcat(${tomcat_home}) process: ${pids}"
        else
            logger "tomcat(${tomcat_home}) process not found"
        fi
    ;;
    monitor)
        pids=$(ps aux | grep tomcat | grep ${tomcat_home} | grep -v 'grep' | grep -v 'tomcat-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            logger "tomcat(${tomcat_home}) process：${pids}"
        else
            logger "tomcat process not found then start tomcat process..."
            logger
            bash $0 ${tomcat_home} startup
            logger
            logger "check tomcat process..."
            logger
            bash $0 ${tomcat_home} monitor
        fi
    ;;
    restart|restartup)
        bash $0 ${tomcat_home} stop
        logger
        logger
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