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

source linux/bash/common.sh

cmd_type="${1:-startup}"
jar_path="$2"
option="${3:-use-header}"

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
            printf "$two_cols_table_format" "${jar_name}" "Jar Package Not Found"
            exit 2
        fi

        printf "$two_cols_table_format" "${jar_name}" "Starting..."

        cd ${jar_dir}
        test -f ${jar_dir}/nohup.out && mv ${jar_dir}/nohup.out ${jar_dir}/nohup.out.$(date +'%y%m%d%H%M%S')
        cmd_nohup="nohup java -jar ${jar_name}"
        exec ${cmd_nohup} >> ${jar_dir}/nohup.out &
        cd -
        
        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{ print $2 }' | xargs)
        printf "$two_cols_table_format" "${jar_name}" "${pids}"
    ;;
    stop)
        if [[ ! -f ${jar_path} ]]; then
            printf "$two_cols_table_format" "${jar_name}" "Not Found"
            exit 2
        fi
        printf "$two_cols_table_format" "${jar_name}" "Stoping..."
        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'service-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            kill -9 ${pids}
            printf "$two_cols_table_format" "${jar_name}" "killing ${pids}"
        else
            printf "$two_cols_table_format" "${jar_name}" "Process Not Found"
        fi
        printf "$two_cols_table_format" "${jar_name}" "Stoped"
    ;;
    status|state)
        if [[ ! -f ${jar_path} ]]; then
            printf "$two_cols_table_format" "${jar_name}" "Jar Package Not Found"
            exit 2
        fi

        pids=$(ps aux | grep ${jar_name} | grep -v 'grep' | grep -v 'jar-service-tools' | awk '{print $2}' | xargs)
        if [ -n "${pids}" ]; then
            printf "$two_cols_table_format" "${jar_name}" "${pids}"
            exit 0
        else
            printf "$two_cols_table_format" "${jar_name}" "-"
            exit 1
        fi
    ;;
    monitor)
        bash $0 status ${jar_path} ${option}
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "${jar_name}" "Process Not Found"
            printf "$two_cols_table_format" "${jar_name}" "Starting..."
            bash $0 startup ${jar_path}
        fi
    ;;
    restart|restartup)
        bash $0 stop ${jar_path}
        bash $0 startup ${jar_path}
    ;;
    auto:generage:praams|agp)
        cat $0 | grep "|*)$" | grep -v echo | awk '{gsub(/ /,"")}1' | awk -F ')' '{print "logger \"    $0 "$1" jar_path\"" }'
    ;;
    help)
        echo "sypctl toolkit jar-service install <jar-path>"
        echo "sypctl toolkit jar-service start <jar-path>"
        echo "sypctl toolkit jar-service stop <jar-path>"
        echo "sypctl toolkit jar-service status <jar-path>"
        echo "sypctl toolkit jar-service restart <jar-path>"
        echo "sypctl toolkit jar-service monitor <jar-path>"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit jar-service help
    ;;
esac