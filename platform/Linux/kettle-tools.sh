#!/usr/bin/env bash
#
########################################
#  
# Kettle Tool
#
# 部署目录: /usr/local/src/kettle-8.2.0.0_342
# 业务文档: /data/work/kettle/jobs
# 定时脚本: /data/work/kettle/scripts
# 
########################################

source platform/Linux/common.sh

package_path=packages/kettle-8.2.0.0_342.tar.gz
package_hash=396cb0c970a88c34142c7acd3129e837
package_install_path=/usr/local/src
package_version=kettle-8.2.0.0_342
package_name="$(basename $package_path)"

case "$1" in
    install)
        fun_print_table_header "Kettle" "PackageName" "FileHash|Deployed"

        if [[ -f ${package_path} ]]; then
            pid_path=${package_path}.pid
            process_state="done"
            if [[ -f "${pid_path}" ]]; then
                pid=$(cat ${pid_path})
                ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
                test $? -eq 0 && process_state="running"
            fi

            if [[ "${process_state}" = "done" ]]; then
                    current_hash=todo
                    command -v md5 > /dev/null && current_hash=$(md5 -q ${package_path})
                    command -v md5sum > /dev/null && current_hash=$(md5sum ${package_path} | cut -d ' ' -f 1)
                    integrity_state=$(test "${package_hash}" = "${current_hash}" && echo 'true' || echo 'false')

                    if [[ "${integrity_state}" = "true" ]]; then
                        if [[ ! -d ${package_install_path}/${package_version} ]]; then
                            tar -xzvf ${package_path} -C ${package_install_path} > /dev/null 2>&1
                            state=$(test $? -eq 0 && echo 'successfully' || echo 'failure')
                            fun_print_two_cols_row "uncompress tar.gz" "${state}"

                            ln -snf ${package_install_path}/${package_version}/spoon.sh /usr/bin/kettle > /dev/null 2>&1
                            state=$(test $? -eq 0 && echo 'successfully' || echo 'failure')
                            fun_print_two_cols_row "create link" "${state}"
                            
                            rm -f /usr/share/applications/kettle.desktop
                            cp config/kettle.desktop /usr/share/applications/ > /dev/null 2>&1
                            chmod a+x /usr/share/applications/kettle.desktop > /dev/null 2>&1
                            state=$(test $? -eq 0 && echo 'successfully' || echo 'failure')
                            fun_print_two_cols_row "create kettle.desktop" "${state}"

                            if [[ -d ~/Desktop ]]; then
                                rm -f ~/Desktop/kettle.desktop
                                cp /usr/share/applications/kettle.desktop ~/Desktop/ > /dev/null 2>&1
                            elif [[ -d ~/桌面 ]]; then
                                rm -f ~/桌面/kettle.desktop
                                cp /usr/share/applications/kettle.desktop ~/桌面 > /dev/null 2>&1
                            else
                                fun_print_two_cols_row "$(whoami) desktop" "NotFound"
                            fi
                            state=$(test $? -eq 0 && echo 'successfully' || echo 'failure')
                            fun_print_two_cols_row "copy $(whoami) kettle.desktop" "${state}"
                        fi

                        fun_print_two_cols_row "${package_install_path}/${package_version}" "true|true"
                    else
                        rm -f ${package_path}
                        fun_print_two_cols_row "${package_name}" "Removed"
                        bash linux/bash/package-downloader.sh ${package_name}
                    fi
            else
                bash linux/bash/package-downloader.sh ${package_name}
            fi
        else
            bash linux/bash/package-downloader.sh ${package_name}
        fi

        fun_print_table_footer
        mkdir -p /data/work/kettle/{jobs,scripts,data,logs}
    ;;
    install:force)
        if [[ -d ${package_install_path}/${package_version} ]]; then
            rm -fr ${package_install_path}/${package_version}
            fun_print_table_header "Kettle" "PackageName" "FileHash|Deployed"
            fun_print_two_cols_row "${package_name}" "Removed"
            fun_print_table_footer
        fi

        bash $0 install
    ;;
    help)
        echo "Kettle 管理:"
        echo "$ sypctl toolkit kettle help"
        echo "$ sypctl toolkit kettle install"
        echo "$ sypctl toolkit kettle install:force"
        echo
        echo "#目录规范#"
        echo "部署目录: /usr/local/src/kettle-8.2.0.0_342"
        echo "业务文档: /data/work/kettle/jobs"
        echo "定时脚本: /data/work/kettle/scripts"
        echo "数据文档: /data/work/kettle/data"
        echo "日志归档: /data/work/kettle/logs"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit kettle help
    ;;
esac