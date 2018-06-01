#!/usr/bin/env bash
#
########################################
#  
#  Linux Date Tool
#
########################################

#!/bin/bash
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

# 限制 100 毫秒
executed_date=$(date +%s)
sinfo=$(curl -sS http://localhost:4567/api/v1/linux.date)
finished_date=$(date +%s)

if [[ ${#sinfo} -ne 23 ]]; then
  echo "格式错误，期望的数据格式 \`+0800 06/01/18 10:33:16\` 长度为 23；而 API 获取到的数据为: \`${sinfo}\`"
  exit
fi

if [[ $finished_date -gt $executed_date ]]; then
    echo "获取超时，耗时 $(expr $finished_date - $executed_date)s，请优化网络后重试"
    exit
fi

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
if [ ${zstr} = ${szstr} ];
then
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
if [ ${dstr} = ${sdstr} ];
then
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
if [ ${hm} = ${shm} ];
then
    echo "本地与校正主机相同时分:"
    echo "本地:${tstr} 校正主机:${ststr}"
else
    echo "修改时间${tstr}=>${ststr}"
    /bin/date -s ${ststr}
    /sbin/clock -w
fi