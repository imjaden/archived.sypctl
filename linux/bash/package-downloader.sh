#!/usr/bin/env bash
#
########################################
#  
#  Package Downloader
#
########################################
#
package_name="$1"
pid_path=linux/packages/${package_name}.pid
log_path=linux/packages/${package_name}.log

source linux/bash/common.sh
process_state="abort"
pid=
if [[ -f "${pid_path}" ]]; then
    pid=$(cat ${pid_path})
    ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
    test $? -eq 0 && process_state="running"
fi

if [[ "$process_state" = "abort" ]]; then
    rm -f ${pid_path}
    rm -f ${log_path}
    rm -f linux/packages/${package_name}
    nohup wget -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}" > ${log_path} 2>&1 & echo $! > ${pid_path}
    pid=$(cat ${pid_path})
    printf "$two_cols_table_format" "${package_name:0:34}" "ToDownload(pid:$pid)"
else
    progress=
    if [[ -f ${log_path} ]]; then
        progress=$(cat ${log_path} | grep -E '\d+%' -o | tail -n 1) # mac
        test -z "${progress}" && progress=$(cat ${log_path} | grep -P '\d+%' -o | tail -n 1) # linux
    fi
    printf "$two_cols_table_format" "${package_name:0:34}" "Downloading(pid:$pid,progress:$progress)"
fi