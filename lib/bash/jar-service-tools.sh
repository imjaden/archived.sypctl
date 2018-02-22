#!/usr/bin/env bash
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
# jar_path="/usr/local/src/providerAPI/api-service.jar"
# cmd_type="startup"
#
# bash service-tools.sh "${jar_path}" "${cmd_type}"
# ```

source lib/bash/common.sh

jar_path="$1"
cmd_type="${2:-startup}"

jar_dir="$(dirname $jar_path)"
jar_name="$(basename $jar_path)"

case "${cmd_type}" in
    install)
        fun_deploy_file_folder ${jar_dir}
    ;;
    log)
        tail -f ${jar_dir}/nohup.out
    ;;
    start|startup)
        if [[ ! -f ${jar_path} ]]; then
            logger "warning: jar package not found - ${jar_path}"  
            exit 2
        fi
        logger "${begin_placeholder} start service process, begin ${begin_placeholder}"

        cd ${jar_dir}
        cmd_nohup="nohup java -jar ${jar_name}"
        exec ${cmd_nohup} >> ${jar_dir}/nohup.out &
        cd -
        
        logger
        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{ print $2 }' | xargs)
        logger "service(${jar_name}) pids: ${pids}"
        logger "${finished_placeholder} start service process, finish ${finished_placeholder}"
    ;;
    stop)
        if [[ ! -f ${jar_path} ]]; then
            logger "warning: jar package not found - ${jar_path}"  
            exit 2
        fi
        logger "${begin_placeholder} stop service process, begin ${begin_placeholder}"
        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            kill -9 ${pids}
            logger "kill service(${jar_name}) pids: ${pids}"
        else
            logger "${jar_name} process not found"
        fi
        logger "${finished_placeholder} stop service process, finish ${finished_placeholder}"
    ;;
    status|state)
        printf "${status_header}" ${status_titles[@]}
        printf "%${status_width}.${status_width}s\n" "${status_divider}"

        if [[ ! -f ${jar_path} ]]; then
            printf "${status_format}" "jar(service)" "master" "jar-404" "${jar_path}"
            exit 2
        fi

        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'jar-service-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            printf "${status_format}" "jar(service)" "master" ${pids} "${jar_path}"
            exit 0
        else
            printf "${status_format}" "jar(service)" "master" "-" "${jar_path}"
            exit 1
        fi
    ;;
    monitor)
        bash $0 ${jar_path} status
        if [[ $? -gt 0 ]]; then
            logger "${jar_name} process not found then start..."
            logger
            bash $0 ${jar_path} startup
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