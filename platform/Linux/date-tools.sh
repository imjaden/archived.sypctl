#!/usr/bin/env bash
#
########################################
#  
#  Linux Date Tool
#
########################################

source platform/Linux/common.sh

#
# 功能：
#     自动校正系统时区、日期、时间
#
# 校正方式一:
#     通过ssh取得远程主机时区、日期、时间为参照校正本机时区、日期、时间
#     此方式需要设置shost=登陆用户名@参照主机ip
#
# 校正方式二:
#     手工设置要修改参考的标准信息
#     此方式需要设置remote_datestr="+0800 09/28/13 16:25:30"
#
# 参数说明：
#
# @remote_api 可选项，校正时间的标准服务 IP;# 无参数时以服务器时间为标准
#
# 完整示例：
#
# ```
# # 场景一
# $ bash date-tools.sh check
# # 场景二，以局域网服务器为标准
# $ bash date-tools.sh check 127.0.0.1
#
#
# # 场景一
# $ bash date-tools.sh view
# # 场景二，以局域网服务器为标准
# $ bash date-tools.sh view 127.0.0.1
# ```
#

api_host=sypctl.com
remote_api=http://${api_host}/api/v1/linux.date

ping -c 1 ${api_host} > /dev/null 2>&1
test $? -eq 0 || {
    echo "警告：无网络环境，退出操作"
    exit 1
} 

function fun_check_linux_date() {
    global_executed_date=$(date +%s)
    test -n "$1" && remote_api="$1"

    if [[ "${remote_api}" = "$(hostname)" ]]; then
        echo "校正的服务器为本机，不作操作！"
        return 1
    fi

    echo "校正标准：${remote_api}"

    executed_date=$(date +%s)
    remote_timestamp=$(curl -sS ${remote_api})
    finished_date=$(date +%s)

    interval=$(expr ${finished_date} - ${executed_date})
    echo "获取标准时间耗时 ${interval} 秒，校正时追加该误差"

    remote_timestamp=$(expr ${remote_timestamp} + ${interval})
    if [[ "$(uname -s)" = "Darwin" ]]; then
        remote_datestr=$(date -r${remote_timestamp} +'%z %m/%d/%y %H:%M:%S')
    else
        remote_datestr=$(date -d @${remote_timestamp} +'%z %m/%d/%y %H:%M:%S')
    fi
    
    if [[ ${#remote_datestr} -ne 23 ]]; then
        echo "Error: 远程服务器的格式化日期长度 != 23, 请修正！"
        echo "       期望的日期格式: $(date +'%z %m/%d/%y %H:%M:%S')"
        exit 1
    fi

    echo "****************************"
    echo "本地时间：$(date +'%z %m/%d/%y %H:%M:%S')"
    echo "标准时间：${remote_datestr}"

    # 修改参考标准时区、日期、时间
    remote_dateinfos=(${remote_datestr})
    remote_zstr=${remote_dateinfos[0]}
    remote_dstr=${remote_dateinfos[1]}
    remote_tstr=${remote_dateinfos[2]}

    # 本地时区、日期、时间
    local_zstr=$(date +%z)
    local_dstr=$(date +%m/%d/%y)
    local_tstr=$(date +%H:%M:%S)
    shanghai=/usr/share/zoneinfo/Asia/Shanghai
    loltime=/etc/localtime

    echo "****************************"
    echo "校正时区"
    if [[ "${local_zstr}" = "${remote_zstr}" ]]; then
        echo "本地与标准时区相同: ${remote_zstr}"
    else
        fun_executed_date=$(date +%s)
        echo "修正日期 ${local_zstr} => ${remote_zstr}"

        if [[ -e ${shanghai} ]] && [[ -e ${loltime} ]]; then
            /bin/mv ${loltime} ${loltime}.bak
            echo "备份${loltime} => ${loltime}.bak"
            /bin/cp ${shanghai} ${loltime}
            echo "覆盖${shanghai} => ${loltime}"
        else
            [[ -e ${shanghai} ]] || echo "${shanghai} 不存在！"
            [[ -e ${loltime} ]] || echo "${loltime} 不存在！"
        fi

        fun_finished_date=$(date +%s)
        fun_interval=$(expr ${fun_finished_date} - ${fun_executed_date})
        echo "运行耗时 ${interval} 秒"
    fi

    echo "****************************"
    echo "校正日期"
    if [[ "${local_dstr}" = "${remote_dstr}" ]]; then
        echo "本地与标准日期相同: ${remote_dstr}"
    else
        fun_executed_date=$(date +%s)
        echo "修正日期 ${local_dstr} => ${remote_dstr}"

        /bin/date -s ${remote_dstr}
        /sbin/clock -w > /dev/null 2>&1

        fun_finished_date=$(date +%s)
        fun_interval=$(expr ${fun_finished_date} - ${fun_executed_date})
        echo "运行耗时 ${interval} 秒"
    fi

    echo "****************************"
    echo "校正时间"
    local_tint=$(echo ${local_tstr} | tr -d ":")
    remote_tint=$(echo ${remote_tstr} | tr -d ":")
    tint_interval=$(expr ${local_tint} - ${remote_tint})
    if [[ ${tint_interval} -gt -3 && ${tint_interval} -lt 3 ]]; then
        echo "本地与标准时分秒相同(误差${tint_interval}秒): ${local_tstr}"
    else
        fun_executed_date=$(date +%s)
        echo "修正时间 ${local_tstr} => ${remote_tstr}"

        /bin/date -s ${remote_tstr}
        /sbin/clock -w > /dev/null 2>&1

        fun_finished_date=$(date +%s)
        fun_interval=$(expr ${fun_finished_date} - ${fun_executed_date})
        echo "运行耗时 ${interval} 秒"
    fi

    echo "****************************"
    echo "耗时报告"
    global_finished_date=$(date +%s)
    global_interval=$(expr ${global_finished_date} - ${global_executed_date})
    global_executed=$(expr ${global_interval} - ${interval})
    echo "整个校正过程耗时 ${global_interval}s, 获取标准时间耗时 ${interval}s, 纯脚本运行耗时 ${global_executed}s"
}

function fun_view_linux_date() {
    test -n "$1" && remote_api="$1"

    echo "对比标准：${remote_api}"

    echo "****************************"
    echo "对比报告"
    executed_date=$(date +%s)
    current_timestamp=$(date +%s)
    remote_timestamp=$(curl -sS ${remote_api})
    finished_date=$(date +%s)

    interval=$(expr ${finished_date} - ${executed_date})
    echo "获取标准时间耗时 ${interval} 秒，对比时追加该误差"

    remote_timestamp=$(expr ${remote_timestamp} + ${interval})
    remote_datestr=$(date -d @${remote_timestamp} +'%z %m/%d/%y %H:%M:%S')
    current_datestr=$(date -d @${current_timestamp} +'%z %m/%d/%y %H:%M:%S')
   
    echo "本地时间：${current_datestr}"
    echo "标准时间：${remote_datestr}"
    echo "误差（秒）：$(expr ${remote_timestamp} - ${current_timestamp})s"
}

case "$1" in
    timestamp)
        echo $(date +%s)
        echo $(date +'%z %m/%d/%y %H:%M:%S')
    ;;
    check)
        if [[ "$2" = "rdate" ]]; then
            command -v rdate > /dev/null || fun_install rdate

            if [[ "${os_type}" = "CentOS" || "${os_type}" = "RedHatEnterpriseServer" ]]; then
                rdate -pl -t 60 -s stdtime.gov.hk
            fi

            if [[ "${os_type}" = "Ubuntu" ]]; then
                rdate -ncv stdtime.gov.hk
            fi

            hwclock -w
        else
            fun_check_linux_date "$2"
        fi
    ;;
    view)
        fun_view_linux_date "$2"
    ;;
    interval)
        test -z "$2" && {
            echo "Error: please pass a timestamp value as param!"
            exit 1
        }

        timestamp="$2"
        now=$(date +%s)
        echo "timestamp: ${timestamp}"
        echo "human: $(date -d @${timestamp} '+%y-%m-%d %H:%M:%S')"
        interval=$(expr $now - $timestamp)
        echo "interval: ${interval}s"
        hours=$(expr $interval / 3600)
        interval=$(expr $interval % 3600)
        minutes=$(expr $interval / 60)
        interval=$(expr $interval % 60)
        echo "human: ${hours}h ${minutes}m ${interval}s"
    ;;
    help)
        echo "日期管理:"
        echo "sypctl toolkit date view      # 查看与服务器日期误差，不作实质修改"
        echo "sypctl toolkit date check     # 对比与服务器日期误差，作实质修改"
        echo "sypctl toolkit date timestamp # 当前日期戳"
        echo "sypctl toolkit date interval <timestamp> # 对比日期戳误差"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit date help
    ;;  
esac