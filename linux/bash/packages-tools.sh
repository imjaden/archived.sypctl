#!/usr/bin/env bash
#
########################################
#  
#  Package Manager(tar.gz)
#
########################################
#

source linux/bash/common.sh
package_list=(nginx-1.11.3.tar.gz@18275c1daa39c5fac12e56c34907d45b apache-tomcat-8.5.24.tar.gz@b21bf4f2293b2e4a33989a2d4f890d5a jdk-8u192-linux-x64.tar.gz@6f1961691877db56bf124d6f50478956 redis-stable.tar.gz@e8fc9b766679196ee70b12d82d4dad0b zookeeper-3.4.12.tar.gz@f43cca610c2e041c71ec7687cddbd0c3 apache-activemq-5.15.5.tar.gz@1e907d255bc2b5761ebc0de53c538d8c)

fun_download_package_when_not_exists() {
  package_name="$1"
  if [[ ! -f linux/packages/${package_name} ]]; then
      printf "$two_cols_table_format" "${package_name}" "Downloading..."
      wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
      printf "$two_cols_table_format" "${package_name}" "Downloaded"
  fi
}
case $1 in
    files)
        fun_print_table_header "Packages List" "PackageName" "FileHash"
        for package_info in ${package_list[@]}; do
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)
            printf "$two_cols_table_format" "${package_name}" "${package_hash}"
        done
        fun_print_table_footer
    ;;
    list)
        fun_print_table_header "Packages List" "PackageName" "Version"
        for package_info in ${package_list[@]}; do
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)
            package=${package_name%-*}
            printf "$two_cols_table_format" "${package}" "${package_name}"
        done
      fun_print_table_footer
    ;;
    check|deploy)
        fun_print_table_header "Packages Integrity State" "PackageName" "Download|Integrity"
        mkdir -p linux/packages
        for package_info in ${package_list[@]}; do
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)
            if [[ -f linux/packages/${package_name} ]]; then
              current_hash=todo
              command -v md5 > /dev/null && current_hash=$(md5 -q linux/packages/${package_name})
              command -v md5sum > /dev/null && current_hash=$(md5sum linux/packages/${package_name} | cut -d ' ' -f 1)

              test "${package_hash}" != "${current_hash}" && rm -f linux/packages/${package_name}
            fi

            fun_download_package_when_not_exists ${package_name}
        done

        clear
        bash $0 state
    ;;
    state|status)
        fun_print_table_header "Packages Download State" "PackageName" "Download|Integrity"
        for package_info in ${package_list[@]}; do
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)
            fun_download_package_when_not_exists ${package_name}

            test -f linux/packages/${package_name}
            download_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')

            current_hash=todo
            command -v md5 > /dev/null && current_hash=$(md5 -q linux/packages/${package_name})
            command -v md5sum > /dev/null && current_hash=$(md5sum linux/packages/${package_name} | cut -d ' ' -f 1)
            test "${package_hash}" != "${current_hash}" && rm -f linux/packages/${package_name}
            integrity_state=$(test "${package_hash}" = "${current_hash}" && echo 'true' || echo 'false')

            printf "$two_cols_table_format" "${package_name}" "${download_state}|${integrity_state}"
        done
        fun_print_table_footer
    ;;
    *)
        echo "安装包管理:"
        echo "sypctl package help         帮助说明"
        echo "sypctl package files        安装包文件"
        echo "sypctl package list         安装包列表"
        echo "sypctl package deploy       下载安装包"
        echo "sypctl package check        查检安装包一致性(文件哈希)"
        echo "sypctl package status       安装包安装状态"
    ;;
esac
