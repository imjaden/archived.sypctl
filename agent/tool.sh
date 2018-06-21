#!/usr/bin/env bash
#
########################################
#  
#  SYP Local Server Command Tool
#
########################################
#
# Usage:
#
# bash /tool.sh {config|start|stop|start_redis|stop_redis|restart|deploy}
#
app_root_path="$(pwd)"
export LANG=zh_CN.UTF-8
while read filepath; do
    test -f "${filepath}" && source "${filepath}"
done < env-files
cd ${app_root_path}

app_default_port=$(cat app-port)
app_port=${2:-${app_default_port}}
app_env=${3:-'production'}

unicorn_config_file=config/unicorn.rb
unicorn_pid_file=tmp/pids/unicorn.pid

bundle_command=$(rbenv which bundle)\
gem_command=$(rbenv which gem)

cd "${app_root_path}" || exit 1
case "$1" in
    bundle)
        $bundle_command install --local > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo -e 'bundle install --local successfully'
        else
            $bundle_command install
        fi
    ;;
    start)
        mkdir -p {logs,tmp/pids}
        $bundle_command exec unicorn -c ${unicorn_config_file} -p ${app_port} -E production -D
        if [[ $? -eq 0 ]]; then
            echo "start unicorn successfully"
        else
            echo "start unicorn failed"
        fi
    ;;
    stop)
        test -f ${unicorn_pid_file} && {
            cat ${unicorn_pid_file} | kill -9
            rm -f ${unicorn_pid_file}
        }
    ;;
    restart)
        bash $0 stop
        bash $0 start
    ;;
    restart:hot)
        cat "${unicorn_pid_file}" | xargs -I pid kill -USR2 pid
    ;;
    process:defender|pd)
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') running($pid)"
            else
                rm -f ${unicorn_pid_file}
                echo "$(date '+%Y-%m-%d %H:%M:%S') starting..."
                bash $0 start
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') starting..."
            bash $0 start
        fi
    ;;
    *)
        echo "warning: unkown params - $@"
    ;;
esac
