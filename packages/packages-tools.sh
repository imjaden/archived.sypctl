
#!/usr/bin/env bash
#
########################################
#  
#  Package Manager(tar.gz)
#
########################################
#
status_divider===============================
status_divider=$status_divider$status_divider
status_titles=(Package Downloaded Integrity)
status_header="\n %-30s %-10s %-10s\n"
status_format=" %-30s %-10s %-10s\n"
status_width=50

case $1 in
    check|deploy)
        package_names=(nginx-1.11.3.tar.gz apache-tomcat-8.5.24.tar.gz jdk-8u151-linux-x64.tar.gz redis-stable.tar.gz zookeeper-3.3.6.tar.gz)
        for package_name in ${package_names[@]}
        do
            if [[ -f packages/${package_name} ]]; then
              tar jtvf packages/${package_name} > /dev/null 2>&1
              if [[ $? -gt 0 ]]; then
                  rm -f packages/${package_name}
              fi
            fi

            if [[ ! -f packages/${package_name} ]]; then
                echo "dwonloading ${package_name} ..."
                wget -q -P packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
                echo "dwonloaded ${package_name}"
            fi
        done

        clear
        bash $0 state
    ;;
    state|status)
      printf "${status_header}" ${status_titles[@]}
      printf "%${status_width}.${status_width}s\n" "${status_divider}"

      package_names=(nginx-1.11.3.tar.gz apache-tomcat-8.5.24.tar.gz jdk-8u151-linux-x64.tar.gz redis-stable.tar.gz zookeeper-3.3.6.tar.gz)
      for package_name in ${package_names[@]}
      do
          if [[ ! -f packages/${package_name} ]]; then
              echo "dwonloading ${package_name} ..."
              wget -P packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
              echo "dwonloaded ${package_name}"
          fi

          test -f packages/${package_name}
          download_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')
          tar jtvf packages/${package_name} > /dev/null 2>&1
          integrity_state=$([[ $? -eq 0 ]] && echo 'true' || echo 'false')

          printf "${status_format}" ${package_name} ${download_state} ${integrity_state}
      done

      fun_printf_timestamp
    ;;
    *)
        bash $0 state
    ;;
esac
