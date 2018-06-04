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

remote_api=http://sypctl-api.ibi.ren/api/v1/linux.date
test -n "$1" && remote_api="$1"

echo ${remote_api}

executed_date=$(date +%s)

test -n "$1" && {
    remote_timestamp=$(ssh ${remote_api} "date +%s")
} || {
    remote_timestamp=$(curl -sS ${remote_api})
}

finished_date=$(date +%s)

interval=$(expr ${finished_date} - ${executed_date})
echo "追加误差 ${interval} 秒"

remote_timestamp=$(expr ${remote_timestamp} + ${interval})
sinfo=$(date -d @${remote_timestamp} +'%z %m/%d/%y %H:%M:%S')

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
if [ ${zstr} = ${szstr} ]; then
    echo "本地与校正主机相同时区:${szstr}"
else
    echo "时区错误:本地时区[${zstr}],校正主机时区[${szstr}]"

    if [ -e ${shanghai} ] && [ -e ${loltime} ];
    then
        /bin/mv ${loltime} ${loltime}.bak
        echo "备份${loltime}=>${loltime}.bak"
        /bin/cp ${shanghai} ${loltime}
        echo "覆盖${shanghai}=>${loltime}"
    else
        [ -e ${shanghai} ] || echo "${shanghai} 不存在！"
        [ -e ${loltime} ]  || echo "${loltime} 不存在！"
    fi
fi

echo "****************************"
echo "校正日期"
if [ ${dstr} = ${sdstr} ]; then
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