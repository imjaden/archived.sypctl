#!/usr/bin/env bash
#
########################################
#  
#  Package Manager(tar.gz)
#
########################################
#

source linux/bash/common.sh
package_names=(nginx-1.11.3.tar.gz apache-tomcat-8.5.24.tar.gz jdk-8u192-linux-x64.tar.gz redis-stable.tar.gz zookeeper-3.4.12.tar.gz apache-activemq-5.15.5.tar.gz)

fun_download_package_when_not_exists() {
  package_name="$1"
  if [[ ! -f linux/packages/${package_name} ]]; then
      printf "$two_cols_table_format" "${package_name}" "Downloading..."
      wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
      printf "$two_cols_table_format" "${package_name}" "Downloaded"
  fi
}
case $1 in
    list)
        fun_print_table_header "Packages List" "PackageName" "Version"
        for package_name in ${package_names[@]}; do
          package=${package_name%-*}
          printf "$two_cols_table_format" "${package}" "${package_name}"
        done
      fun_print_table_footer
    ;;
    check|deploy)
        fun_print_table_header "Packages Integrity State" "PackageName" "Download|Integrity"
        mkdir -p linux/packages
        for package_name in ${package_names[@]}; do
            if [[ -f linux/packages/${package_name} ]]; then
              tar -jtvf linux/packages/${package_name} > /dev/null 2>&1
              test $? -gt 0 && rm -f linux/packages/${package_name}
            fi

            fun_download_package_when_not_exists ${package_name}
        done

        clear
        bash $0 state
    ;;
    state|status)
        fun_print_table_header "Packages Download State" "PackageName" "Download|Integrity"
        for package_name in ${package_names[@]}; do
            fun_download_package_when_not_exists ${package_name}

            test -f linux/packages/${package_name}
            download_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')
            tar jtvf linux/packages/${package_name} > /dev/null 2>&1
            integrity_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')

            printf "$two_cols_table_format" "${package_name}" "${download_state}|${integrity_state}"
        done
        fun_print_table_footer
    ;;
    *)
        echo "安装包管理:"
        echo "sypctl package help         帮助说明"
        echo "sypctl package list         安装包列表"
        echo "sypctl package deploy       下载安装包"
        echo "sypctl package check        查检安装包一致性(文件哈希)"
        echo "sypctl package status       安装包安装状态"
    ;;
esac
