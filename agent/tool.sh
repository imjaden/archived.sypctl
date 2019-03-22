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
export LANG=zh_CN.UTF-8

app_root_path="$(pwd)"
test -f ../.env-files || touch ../.env-files
while read filepath; do
    source "${filepath}" > /dev/null 2>&1
done < ../.env-files
cd ${app_root_path}

mkdir -p {monitor/{index,pages},logs,tmp/pids,db,jobs,.config}
unicorn_config_file=config/unicorn.rb
unicorn_pid_file=tmp/pids/unicorn.pid

function title() { printf "########################################\n# %s\n########################################\n" "$1"; }
function check_deploy_tate() {
    if [[ -f .config/local-server ]]; then
        test -f .config/app-port || echo 8086 > .config/app-port
        test -f .config/app-workers || echo 1 > .config/app-workers
    else
        echo
        title "提示：本地未部署代理端服务"
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
    deploy:force)
        rm -fr .config/local-server
        bash $0 deploy
    ;;
    deploy)
        if [[ -f .config/local-server ]]; then
            bash $0 state
        else
            read -p "确定部署代理端服务? y/n: " user_input
            if [[ "${user_input}" = 'y' ]]; then
                echo $(date +'%Y%m%d%H%M%S') > .config/local-server
             
                read -p "请输入代理端服务端口号，默认 8086: " user_input
                echo ${user_input:-8086} > .config/app-port

                read -p "请输入代理端服务进程数量，默认 1: " user_input
                echo ${user_input:-1} > .config/app-workers

                if [[ -f ~/.bash_profile ]]; then
                    [[ $(uname -s) = "Darwin" ]] && env_path=$(greadlink -f ~/.bash_profile) || env_path=$(readlink -f ~/.bash_profile)
                    echo "${env_path}" > .config/env-files
                fi

                password=""
                for n in 1 2 3 4 5 6; do
                    password="${password}$(($RANDOM%10))"
                done
                echo ${password} > .config/password
                echo sypagent    > .config/username
                read -p "代理端服务账号: sypagent/${password}"

                title "$ 预检部署配置"
                bash $0 bundle

                title "$ 启动服务"
                bash $0 process:defender

                title "$ 服务动态状态"
                bash $0 state

                title "$ 提交配置信息"
                sypctl agent:task guard FORCE_SYNC_AGENT_INFO=true
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
    start:dev)
        check_deploy_tate
    
        app_port=$(cat .config/app-port)
        echo "\$ bundle exec unicorn -p ${app_port}"
        bundle exec unicorn -p ${app_port}
    ;;
    start)
        title '启动代理服务'
        check_deploy_tate
    
        app_port=$(cat .config/app-port)

        bash $0 bundle
        bundle exec unicorn -c ${unicorn_config_file} -p ${app_port} -E production -D
        test  $? -eq 0 && echo "启动代理服务成功" || echo "启动代理服务失败"

        echo
        bash $0 state
    ;;
    stop)
        title '关闭代理服务'
        check_deploy_tate

        if [[ -f ${unicorn_pid_file} ]]; then
            cat ${unicorn_pid_file} | xargs kill -9 > /dev/null 2>&1
            echo "关闭代理服务成功($(cat $unicorn_pid_file))"
            rm -f ${unicorn_pid_file}
        else 
            echo "代理服务未启动"
        fi
    ;;
    restart)
        title '重启代理服务'
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

        title "代理服务状态"
        echo "端口号: $(cat .config/app-port)"
        echo "进程数: $(cat .config/app-workers)"
        
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "进程ID: $pid"
            else
                rm -f ${unicorn_pid_file}
                echo "进程ID: 未运行"
            fi
        else
            echo "服务进程已关闭"
        fi
    ;;
    process:defender|daemon)
        if [[ -f ${unicorn_pid_file} ]]; then
            pid=$(cat ${unicorn_pid_file})
            ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
            if [[ $? -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') 代理服务端口号: $(cat .config/app-port)"
                echo "$(date '+%Y-%m-%d %H:%M:%S') 代理端服务进程: $(cat .config/app-workers)"
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
        title '移除代理服务'
        check_deploy_tate

        read -p "确定移除代理端服务? y/n: " user_input
        if [[ "${user_input}" = 'y' ]]; then
            bash $0 stop
            rm -f .config/local-server
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
