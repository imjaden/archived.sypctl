#!/usr/bin/env bash
#
########################################
#  
#  Package Manager(tar.gz)
#
########################################
#

source server/bash/common.sh

case $1 in
    check|deploy)
        fun_print_table_header "Packages State" "PackageName" "Download/Integrity"

        mkdir -p server/packages
        package_names=(nginx-1.11.3.tar.gz apache-tomcat-8.5.24.tar.gz jdk-8u151-linux-x64.tar.gz redis-stable.tar.gz zookeeper-3.3.6.tar.gz)
        for package_name in ${package_names[@]}
        do
            if [[ -f server/packages/${package_name} ]]; then
              tar jtvf packages/${package_name} > /dev/null 2>&1
              if [[ $? -gt 0 ]]; then
                  rm -f server/packages/${package_name}
              fi
            fi

            if [[ ! -f server/packages/${package_name} ]]; then
                printf "$two_cols_table_format" "${package_name}" "Downloading..."
                wget -q -P server/packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
                printf "$two_cols_table_format" "${package_name}" "Downloaded"
            fi
        done

        clear
        bash $0 state
    ;;
    state|status)
      fun_print_table_header "Packages State" "PackageName" "Download/Integrity"

      package_names=(nginx-1.11.3.tar.gz apache-tomcat-8.5.24.tar.gz jdk-8u151-linux-x64.tar.gz redis-stable.tar.gz zookeeper-3.3.6.tar.gz)
      for package_name in ${package_names[@]}
      do
          if [[ ! -f server/packages/${package_name} ]]; then
              printf "$two_cols_table_format" "${package_name}" "Downloading..."
              wget -q -P server/packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
              printf "$two_cols_table_format" "${package_name}" "Downloaded"
          fi

          test -f server/packages/${package_name}
          download_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')
          tar jtvf server/packages/${package_name} > /dev/null 2>&1
          integrity_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')

          printf "$two_cols_table_format" "${package_name}" "${download_state}|${integrity_state}"
      done
    ;;
    *)
        bash $0 state
    ;;
esac
