#!/usr/bin/env bash
#
########################################
#  
#  Linux Date Tool
#
########################################
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
# @remote_api   可选项，校正时间的标准服务 IP;# 无参数时以服务器时间为标准
#
# 完整示例：
#
# ```
# # 场景一
# $ bash date-tools.sh
# # 场景二，以局域网服务器为标准
# $ bash date-tools.sh 127.0.0.1
# ```


global_executed_date=$(date +%s)

remote_api=http://sypctl-api.ibi.ren/api/v1/linux.date
test -n "$1" && remote_api="$1"

echo "校正标准：${remote_api}"

executed_date=$(date +%s)
test -n "$1" && remote_timestamp=$(ssh ${remote_api} "date +%s") || remote_timestamp=$(curl -sS ${remote_api})
finished_date=$(date +%s)

interval=$(expr ${finished_date} - ${executed_date})
echo "获取标准时间耗时 ${interval} 秒，校正时追加该误差"

remote_timestamp=$(expr ${remote_timestamp} + ${interval})
remote_datestr=$(date -d @${remote_timestamp} +'%z %m/%d/%y %H:%M:%S')

if [[ ${#remote_datestr} -ne 23 ]]; then
    echo "Error: 远程服务器的格式化日期长度 != 23, 请修正！"
    echo "       期望的日期格式: $(date +'%z %m/%d/%y %H:%M:%S')"
    exit 1
fi

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
if [[] ${local_zstr} = ${remote_zstr} ]]; then
    echo "本地与校正主机相同时区: ${remote_zstr}"
else
    echo "时区错误:本地时区[${local_zstr}], 校正主机时区[${remote_zstr}]"

    if [[ -e ${shanghai} ]] && [[ -e ${loltime} ]]; then
        /bin/mv ${loltime} ${loltime}.bak
        echo "备份${loltime} => ${loltime}.bak"
        /bin/cp ${shanghai} ${loltime}
        echo "覆盖${shanghai} => ${loltime}"
    else
        [[ -e ${shanghai} ]] || echo "${shanghai} 不存在！"
        [[ -e ${loltime} ]] || echo "${loltime} 不存在！"
    fi
fi

echo "****************************"
echo "校正日期"
if [[ ${local_dstr} = ${remote_dstr} ]]; then
    echo "本地与校正主机相同日期: ${remote_dstr}"
else
    echo "修改日期${local_dstr} => ${remote_dstr}"
    /bin/date -s ${remote_dstr}
    /sbin/clock -w
fi

echo "****************************"
echo "校正时间"
local_hm=$(echo ${local_tstr} | cut -c 1-5)
remote_hm=$(echo ${remote_ststr} | cut -c 1-5)
if [[ ${local_hm} = ${remote_hm} ]]; then
    echo "本地与校正主机相同时分:"
    echo "本地: ${local_tstr} 校正主机:${remote_tstr}"
else
    echo "修改时间 ${local_tstr} => ${remote_tstr}"
    /bin/date -s ${remote_tstr}
    /sbin/clock -w
fi

echo "****************************"
global_finished_date=$(date +%s)
global_interval=$(expr ${global_finished_date} - ${global_executed_date})
global_executed=$(expr ${global_interval} - ${interval})
echo "整个校正过程耗时 ${global_interval}s, 获取标准时间耗时 ${interval}s, 纯脚本运行耗时 ${global_executed}s"