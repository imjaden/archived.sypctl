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

test -f app-port && app_default_port=$(cat app-port) || app_default_port=8086
app_port=${2:-${app_default_port}}
app_env=${3:-'production'}

unicorn_config_file=config/unicorn.rb
unicorn_pid_file=tmp/pids/unicorn.pid

bundle_command=$(rbenv which bundle)
gem_command=$(rbenv which gem)

cd "${app_root_path}" || exit 1
function title() { printf "\n%s\n\n" "$1"; }
case "$1" in
    deploy)
        if [[ -f local-sypctl-server ]]; then
            bash $0 state
        else
            read -p "确定部署 agent server? y/n: " user_input
            [[ "${user_input}" = 'y' ]] && echo ${timestamp} > local-sypctl-server
         
            read -p "请输入 agent server 服务端口号，默认 8086: " user_input
            echo ${user_input:-8086} > app-port

            title "$ bundle install"
            bash $0 bundle

            title "$ start agent server"
            bash $0 process:defender

            title "$ agent server state"
            bash $0 state
        fi
    ;;
    bundle)
        $bundle_command install --local > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo -e 'bundle install --local successfully'
        else
            $bundle_command install
        fi
    ;;
    start)
        mkdir -p {monitor/{index,pages},logs,tmp/pids,db,jobs}
        $bundle_command exec unicorn -c ${unicorn_config_file} -p ${app_port} -E production -D
        if [[ $? -eq 0 ]]; then
            echo "start agent server successfully"
        else
            echo "start agent server failed"
        fi
    ;;
    stop)
        if [[ -f ${unicorn_pid_file} ]]; then
            cat ${unicorn_pid_file} | xargs kill -9
            rm -f ${unicorn_pid_file}
            echo "stop agent server successfully"
        else
            echo "stop agent server failed"
        fi
    ;;
    restart)
        bash $0 stop
        bash $0 start

        title "$ agent server state"
        bash $0 state
    ;;
    restart:hot)
        cat "${unicorn_pid_file}" | xargs -I pid kill -USR2 pid
    ;;
    state)
        if [[ -f local-sypctl-server ]]; then
            echo "本地已部署 sypctl agent server"
            test -f app-port && echo "agent server port: $(cat app-port)" || echo "agent server port: no config"
            
            if [[ -f ${unicorn_pid_file} ]]; then
                pid=$(cat ${unicorn_pid_file})
                /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
                if [[ $? -eq 0 ]]; then
                    echo "agent server is running($pid)"
                else
                    rm -f ${unicorn_pid_file}
                    echo "agent server is stoped"
                fi
            else
                echo "agent server is stoped"
            fi
        else
            echo "本地未部署 sypctl agent server"
            echo 
            bash $0 help
            exit 1
        fi
    ;;
    process:defender|daemon)
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') agent server is running($pid)"
            else
                rm -f ${unicorn_pid_file}
                echo "$(date '+%Y-%m-%d %H:%M:%S') starting agent server..."
                bash $0 start
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') starting agent server..."
            bash $0 start
        fi
    ;;
    remove)
        if [[ -f local-sypctl-server ]]; then
            read -p "确定移除 agent server? y/n: " user_input
            if [[ "${user_input}" = 'y' ]]; then
                bash $0 stop
                rm -f local-sypctl-server
                rm -f app-port
                bash $0 bundle > /dev/null 2>&1
                echo "移除 agent server 成功"
                echo
                bash $0 help
            else
                bash $0 state
            fi
        else
            title "本地未部署 agent server，未执行移除操作"
        fi
    ;;
    help)
        echo "Usage: sypctl agent:server <command>"
        echo 
        commands=(help deploy start stop restart state remove)
        for cmd in ${commands[@]}; do
            echo "sypctl agent:server ${cmd}"
        done
    ;;
    *)
        echo "warning: unkown command - <$@>"
        bash $0 help
    ;;
esac
