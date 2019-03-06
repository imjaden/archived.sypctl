#!/usr/bin/env bash
#
########################################
#  
#  Package Manager(tar.gz)
#
########################################
#

source linux/bash/common.sh
# package_list=(nginx-1.11.3.tar.gz@18275c1daa39c5fac12e56c34907d45b apache-tomcat-8.5.24.tar.gz@b21bf4f2293b2e4a33989a2d4f890d5a apache-activemq-5.15.5.tar.gz@1e907d255bc2b5761ebc0de53c538d8c jdk-1.8.0_192.tar.gz@910288747afd1792926d1b9bcd2a7844 redis-4.0.6.tar.gz@161a6ec82a82dcf38259347833aab707 mysql-5.7.25.tar.gz@cdbc989191e4fd075384d452724d027f zookeeper-3.4.12.tar.gz@f43cca610c2e041c71ec7687cddbd0c3 kettle-8.2.0.0_342.tar.gz@396cb0c970a88c34142c7acd3129e837 kettle-8.2.0.0_342-plugins_hadoop-configurations.tar.gz@145aaa06d65eaf2361e2e7e53fda739a mysql-connector-java-8.0.11.jar@39f2510f19364d9d883b6c00b7ec13b3)
declare -a package_list
package_list[0]=nginx-1.11.3.tar.gz@18275c1daa39c5fac12e56c34907d45b
package_list[1]=apache-tomcat-8.5.24.tar.gz@b21bf4f2293b2e4a33989a2d4f890d5a
package_list[2]=apache-activemq-5.15.5.tar.gz@1e907d255bc2b5761ebc0de53c538d8c
package_list[3]=jdk-1.8.0_192.tar.gz@910288747afd1792926d1b9bcd2a7844
package_list[4]=redis-4.0.6.tar.gz@161a6ec82a82dcf38259347833aab707
package_list[5]=mysql-5.7.25.tar.gz@cdbc989191e4fd075384d452724d027f
package_list[6]=zookeeper-3.4.12.tar.gz@f43cca610c2e041c71ec7687cddbd0c3
package_list[7]=kettle-8.2.0.0_342.tar.gz@396cb0c970a88c34142c7acd3129e837
package_list[8]=kettle-8.2.0.0_342-plugins_hadoop-configurations.tar.gz@145aaa06d65eaf2361e2e7e53fda739a
package_list[9]=mysql-connector-java-8.0.11.jar@39f2510f19364d9d883b6c00b7ec13b3
package_list[10]=go1.12.darwin-amd64.tar.gz@2e50819b23f3b97eb4da9a154de48d95
package_list[11]=go1.12.linux-amd64.tar.gz@feca904457dca812b1840cd98c5d0ae1

case $1 in
    files)
        for index in ${!package_list[@]}; do
            package_info=${package_list[$index]}
            echo $package_info
        done
    ;;
    list)
        fun_print_table_header "PackagesList" "PackageName" "Hash"
        for index in ${!package_list[@]}; do
            package_info=${package_list[$index]}
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)
            package=${package_name%-*}
            fun_print_two_cols_row "${index}, ${package_name}" "${package_hash}"
        done
        fun_print_table_footer
    ;;
    state|status|check|deploy)
        fun_print_table_header "PackagesState" "PackageName" "Download|Hash"
        for package_info in ${package_list[@]}; do
            package_name=$(echo $package_info | cut -d @ -f 1)
            package_hash=$(echo $package_info | cut -d @ -f 2)

            if [[ ! -f linux/packages/${package_name} ]]; then
                bash linux/bash/package-downloader.sh ${package_name}
            fi

            download_state=false
            integrity_state=false
            if [[ -f linux/packages/${package_name} ]]; then
                pid_path=linux/packages/${package_name}.pid
                process_state="done"
                if [[ -f "${pid_path}" ]]; then
                    pid=$(cat ${pid_path})
                    ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
                    test $? -eq 0 && process_state="running"
                fi

                if [[ "${process_state}" = "done" ]]; then
                    download_state=true
                    current_hash=todo
                    command -v md5 > /dev/null && current_hash=$(md5 -q linux/packages/${package_name})
                    command -v md5sum > /dev/null && current_hash=$(md5sum linux/packages/${package_name} | cut -d ' ' -f 1)
                    integrity_state=$(test "${package_hash}" = "${current_hash}" && echo 'true' || echo 'false')
                    fun_print_two_cols_row "${package_name}" "${download_state}|${integrity_state}"

                    if [[ "${integrity_state}" = "true" ]]; then
                        mkdir -p {tmp,logs}
                        test -f linux/packages/${package_name}.pid && mv linux/packages/${package_name}.pid tmp
                        test -f linux/packages/${package_name}.log && mv linux/packages/${package_name}.log logs
                    else
                        rm -f linux/packages/${package_name}
                        fun_print_two_cols_row "${package_name}" "Removed"
                        bash linux/bash/package-downloader.sh ${package_name}
                    fi
                else
                    bash linux/bash/package-downloader.sh ${package_name}
                fi
            fi
        done
        fun_print_table_footer
    ;;
    help)
        echo "安装包管理:"
        echo "sypctl toolkit package help     帮助说明"
        echo "sypctl toolkit package list     安装包列表"
        echo "sypctl toolkit package status   安装包下载状态/哈希一致性,未下载则自动下载"
        echo "sypctl toolkit package deploy   下载安装包，功能同 status"
        echo "sypctl toolkit package check    检查安装包，功能同 status"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo

        sypctl toolkit package help
    ;;
esac
