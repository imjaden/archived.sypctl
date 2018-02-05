#!/bin/bash
#
########################################
#  
#  Service Process Manager(Jar)
#
########################################
#
# 参数说明:(传参顺序必须一致)
#
# @jar_path      jar 包绝对路径
# @cmd_type      执行 jar 的命令，支持 shutdown/startup/restartup, 默认 startup
#
# 完整示例：
#
# ```
# cmd_type="startup"
# jar_path="/usr/local/src/providerTelecomApi/portal-api-service-1.0-SNAPSHOT.jar"
#
# bash service-tools.sh "${cmd_type}" "${jar_path}"
# ```

jar_path="$1"
cmd_type="${2:-startup}"

test -f ~/.bash_profile && source ~/.bash_profile

logger() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

if [[ "${cmd_type}" != "agp" && ! -f ${jar_path} ]]; then
    logger "warning: jar package not found - ${jar_path}" && exit
fi

jar_dir="$(dirname $jar_path)"
jar_name="$(basename $jar_path)"
begin_placeholder=">>>>>>>>>>"
finished_placeholder="<<<<<<<<<<"

case "${cmd_type}" in
    log)
        cd ${jar_dir}
        tail -f nohup.out
    ;;
    start|startup)
        logger "${begin_placeholder} start service process, begin ${begin_placeholder}"

        cd ${jar_dir}
        cmd_nohup="nohup java -jar ${jar_name}"
        exec ${cmd_nohup} >> ${jar_dir}/nohup.out &
        cd -
        
        logger
        service_pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{ print $2 }' | xargs)
        logger "进程 pid: ${service_pids}"
        logger "${finished_placeholder} start service process, finish ${finished_placeholder}"
    ;;
    stop)
        logger "${begin_placeholder} stop service process, begin ${begin_placeholder}"
        service_pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{print $2}' | xargs)
        if [ -n "${service_pids}" ]; then
            kill -9 ${service_pids}
            logger "kill service(${jar_name}) process：${service_pids}"
        else
            logger "${jar_name} process not found"
        fi
        logger "${finished_placeholder} stop service process, finish ${finished_placeholder}"
    ;;
    status|state)
        service_pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{print $2}' | xargs)
        if [ -n "${service_pids}" ]; then
            logger "service(${jar_name}) process: ${service_pids}"
        else
            logger "${jar_name} process not found"
        fi
    ;;
    monitor)
        service_pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{print $2}' | xargs)
        if [ -n "${service_pids}" ]; then
            logger "service(${jar_name}) process: ${service_pids}"
        else
            logger "${jar_name} process not found then start..."
            logger
            bash $0 ${jar_path} startup
            logger
            logger "check ${jar_name} process..."
            logger
            bash $0 ${jar_path} monitor
        fi
    ;;
    restart|restartup)
        bash $0 ${jar_path} stop
        logger
        logger 
        bash $0 ${jar_path} startup
    ;;
    auto:generage:praams|agp)
        cat $0 | grep "|*)$" | grep -v echo | awk '{gsub(/ /,"")}1' | awk -F ')' '{print "logger \"    $0 "$1" jar_path\"" }'
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 jar_path start"
        logger "    $0 jar_path stop"
        logger "    $0 jar_path status|state"
        logger "    $0 jar_path monitor"
        logger "    $0 jar_path restart"
        logger "    $0 jar_path auto:generage:praams|agp"
    ;;
esac