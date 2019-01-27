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
test -f env-files && while read filepath; do
    test -f "${filepath}" && source "${filepath}"
done < env-files
cd ${app_root_path}

test -f app-port && app_default_port=$(cat app-port) || app_default_port=8086
app_port=${2:-${app_default_port}}
app_env=${3:-'production'}

unicorn_config_file=config/unicorn.rb
unicorn_pid_file=tmp/pids/unicorn.pid

cd "${app_root_path}" || exit 1
function title() { printf "\n%s\n\n" "$1"; }
function check_deploy_tate() {
    if [[ ! -f local-sypctl-server ]]; then
        echo
        echo "提示：本地未部署代理端服务"
        echo
        echo "部署服务请执行："
        echo "\$ sypctl agent:server deploy"
        echo
        echo "查看命令请执行："
        echo "\$ sypctl agent:server help"
        echo
        exit 1
    fi
}
case "$1" in
    check)
    ;;
    deploy)
        if [[ -f local-sypctl-server ]]; then
            bash $0 state
        else
            read -p "确定部署代理端服务? y/n: " user_input
            if [[ "${user_input}" = 'y' ]]; then
                echo ${timestamp} > local-sypctl-server
             
                read -p "请输入代理端服务端口号，默认 8086: " user_input
                echo ${user_input:-8086} > app-port

                read -p "请输入代理端服务进程数量，默认 1: " user_input
                echo ${user_input:-1} > app-worker-processes

                if [[ -f ~/.bash_profile ]]; then
                    [[ $(uname -s) = "Darwin" ]] && env_path=$(greadlink -f ~/.bash_profile) || env_path=$(readlink -f ~/.bash_profile)
                    echo "${env_path}" > env-files
                fi

                title "$ 部署预检"
                bash $0 bundle

                title "$ 启动服务"
                bash $0 process:defender

                title "$ 服务状态"
                bash $0 state
            else
                echo "退出部署引导！"
            fi
        fi
    ;;
    bundle)
        bundle install --local > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo -e '启动预检测成功'
        else
            echo -e '启动预检测异常，重检...'
            bundle install > /dev/null 2>&1
            echo -e '启动预重检完成'
        fi
    ;;
    start)
        check_deploy_tate

        mkdir -p {monitor/{index,pages},logs,tmp/pids,db,jobs}
        bash $0 bundle
        
        bundle exec unicorn -c ${unicorn_config_file} -p ${app_port} -E production -D
        test  $? -eq 0 && echo "启动代理服务成功" || echo "启动代理服务失败"

        curl http://127.0.0.1:${app_port}/ > /dev/null 2>&1
    ;;
    stop)
        check_deploy_tate

        if [[ -f ${unicorn_pid_file} ]]; then
            cat ${unicorn_pid_file} | xargs kill -9 > /dev/null 2>&1
            rm -f ${unicorn_pid_file}
            echo "关闭代理服务成功"
        else 
            echo "代理服务未启动"
        fi
    ;;
    restart)
        check_deploy_tate

        bash $0 stop
        bash $0 start

        title "$ agent server state"
        bash $0 state
    ;;
    restart:hot)
        check_deploy_tate

        cat "${unicorn_pid_file}" | xargs -I pid kill -USR2 pid
    ;;
    state|status)
        check_deploy_tate

        echo "本地已部署代理端服务："
        test -f app-port && echo "代理服务端口号: $(cat app-port)" || echo "代理端服务端口号: NoConfig"
        test -f app-worker-processes && echo "代理端服务进程: $(cat app-worker-processes)" || echo "代理端服务进程: NoConfig"
        
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "代理服务进程ID: $pid"
            else
                rm -f ${unicorn_pid_file}
                echo "代理服务进程ID: 未运行"
            fi
        else
            echo "代理服务进程已关闭"
        fi
    ;;
    process:defender|daemon)
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') 代理服务端口号: $(cat app-port)"
                echo "$(date '+%Y-%m-%d %H:%M:%S') 代理端服务进程: $(cat app-worker-processes)"
                echo "$(date '+%Y-%m-%d %H:%M:%S') 代理服务进程ID: $pid"
            else
                rm -f ${unicorn_pid_file}
                echo "$(date '+%Y-%m-%d %H:%M:%S') 启动代理服务..."
                bash $0 start
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') 启动代理服务..."
            bash $0 start
        fi
    ;;
    remove)
        check_deploy_tate

        read -p "确定移除代理端服务? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            bash $0 stop
            rm -f local-sypctl-server
            rm -f app-port
            rm -f app-worker-processes
            bash $0 bundle
            echo "移除代理端服务成功"
            echo
            bash $0 help
        else
            bash $0 state
        fi
    ;;
    help)
        echo "Usage: sypctl agent:server <command>"
        echo 
        commands=(help deploy start stop restart status remove)
        for cmd in ${commands[@]}; do
            echo "sypctl agent:server ${cmd}"
        done
    ;;
    *)
        echo "warning: unkown command - <$@>"
        bash $0 help
    ;;
esac
