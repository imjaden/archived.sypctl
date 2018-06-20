#!/usr/bin/env bash
#
########################################
#  
#  Linux Date Tool
#
########################################

source linux/bash/common.sh

# 功能：
#     自动校正系统时区、日期、时间
# 校正方式一:
#     通过ssh取得远程主机时区、日期、时间为参照校正本机时区、日期、时间
#     此方式需要设置shost=登陆用户名@参照主机ip
#
# 校正方式二:
#     手工设置要修改参考的标准信息
#     此方式需要设置sinfo="+0800 09/28/13 16:25:30"
#
# 说明:
#     默认使用校正方式一,方式二被注释;
#     若使用校正方式二，需把校正方式一代码注释

# 无参数时以服务器时间为标准，
# 传 IP 参数时，以此服务器时间为标题
function fun_sypctl_date_checker() {
    sinfo=""
    test -n "$1" && {
        sinfo=$(ssh "$1" "date +'%z %m/%d/%y %H:%M:%S'")
        echo "$1"
    } || {
        echo "http://sypctl-api.ibi.ren/api/v1/linux.date"
        function get_sypctl_server_date() {
            executed_date=$(date +%s)
            sinfo=$(curl -sS http://sypctl-api.ibi.ren/api/v1/linux.date)
            finished_date=$(date +%s)

            if [[ ${#sinfo} -ne 23 ]]; then
              echo "格式错误，期望的数据格式 \`+0800 06/01/18 10:33:16\` 长度为 23；而 API 获取到的数据为: \`${sinfo}\`"
              return 1
            fi

            interval=$(expr ${finished_date} - ${executed_date})
            if [[ ${interval} -gt 0 ]]; then
                echo "获取超时，耗时 ${interval}s，请优化网络后重试" # 必须同一秒内完成获取服务器时间操作，否则失效
                return 1
            fi
            return 0
        }

        try_times=1
        try_times_limit=4
        local_date_state=1
        while [[ ${local_date_state} -gt 0 && ${try_times} -lt ${try_times_limit} ]]; do
            [[ ${try_times} -gt 1 ]] && echo "第 ${trynum} 次尝试校正系统时区"

            get_sypctl_server_date
            
            local_date_state=$?
            try_times=$(expr ${try_times} + 1)
        done
    }

    # 修改参考标准时区、日期、时间
    infos=(${sinfo})
    szstr=${infos[0]}
    sdstr=${infos[1]}
    ststr=${infos[2]}

    # 本地时区、日期、时间
    zstr=$(date +%z)
    dstr=$(date +%m/%d/%y)
    tstr=$(date +%H:%M:%S)
    shanghai=/usr/share/zoneinfo/Asia/Shanghai
    loltime=/etc/localtime

    echo "****************************"
    echo "校正时区"
    if [[ ${zstr} = ${szstr} ]]; then
        echo "本地与校正主机相同时区:${szstr}"
    else
        echo "时区错误:本地时区[${zstr}],校正主机时区[${szstr}]"

        if [[ -e ${shanghai} && -e ${loltime} ]]; then
            /bin/mv ${loltime} ${loltime}.bak
            echo "备份${loltime}=>${loltime}.bak"
            /bin/cp ${shanghai} ${loltime}
            echo "覆盖${shanghai}=>${loltime}"
        else
            [[ -e ${shanghai} ]] || echo "${shanghai} 不存在！"
            [[ -e ${loltime} ]]  || echo "${loltime} 不存在！"
        fi
    fi

    echo "****************************"
    echo "校正日期"
    if [[ ${dstr} = ${sdstr} ]]; then
        echo "本地与校正主机相同日期:${sdstr}"
    else
        echo "修改日期${dstr}=>${sdstr}"
        /bin/date -s ${sdstr}
        /sbin/clock -w
    fi

    echo "****************************"
    echo "校正时间"
    hm=$(echo ${tstr} | cut -c 1-5)
    shm=$(echo ${ststr} | cut -c 1-5)
    if [ ${hm} = ${shm} ]; then
        echo "本地与校正主机相同时分:"
        echo "本地:${tstr} 校正主机:${ststr}"
    else
        echo "修改时间${tstr}=>${ststr}"
        /bin/date -s ${ststr}
        /sbin/clock -w
    fi
}

case "$1" in
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
            fun_sypctl_date_checker "$2"
        fi
    ;;
    view)
        date +'%z %m/%d/%y %H:%M:%S'
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
    *)
        echo "bash $0 view|check"
    ;;  
esac