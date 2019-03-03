#!/usr/bin/env bash
#
########################################
#  
#  Version Download Downloader
#
########################################
#
version_url="$1"
version_name="$2"
version_path="$3"
version_file="$3/$2"
pid_path="${version_file}.pid"
log_path="${version_file}.log"

process_state="todo"
pid=
if [[ -f "${pid_path}" ]]; then
    pid=$(cat ${pid_path})
    ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
    test $? -eq 0 && process_state="running" || process_state="done" 
fi

if [[ "$process_state" = "todo" ]]; then
    rm -f ${pid_path} ${log_path} ${version_file}
    nohup wget -S -c -t 3 -T 120 -P "${version_path}" "${version_url}" > ${log_path} 2>&1 & echo $! > ${pid_path}
    pid=$(cat ${pid_path})
    echo "pid:$pid"
else
    progress=
    if [[ -f ${log_path} ]]; then
        progress=$(cat ${log_path} | grep -E '\d+% \S+ \S+$' -o | tail -n 1) # mac
        test -z "${progress}" && progress=$(cat ${log_path} | grep -P '\d+% \S+ \S+$' -o | tail -n 1) # linux
    fi
    echo "pid:$pid,progress:$progress"
fi
