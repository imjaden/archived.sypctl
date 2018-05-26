#!/usr/bin/env bash
#
########################################
#  
#  Redis Tool
#
########################################

source linux/bash/common.sh

case "$1" in
    check)
        command -v redis-cli >/dev/null 2>&1 && fun_prompt_redis_already_installed || echo "warning: redis-cli command not found"
    ;;
    install|deploy)
        command -v redis-cli >/dev/null 2>&1 && {
            fun_prompt_redis_already_installed
            exit 1
        }
        
        redis_package=linux/packages/redis-stable.tar.gz
        redis_install_path=/usr/local/src
        redis_version=redis-stable

        if [[ -d ${redis_install_path}/${redis_version} ]]; then
            rm -fr ${redis_install_path}/${redis_version} 
            printf "$two_cols_table_format" "Redis package" "Removed Useless Package"
        fi

        if [[ ! -f ${redis_package} ]]; then
            printf "$two_cols_table_format" "Redis package" "Not Found"
            printf "$two_cols_table_format" "Redis package" "Downloading..."

            mkdir -p linux/packages
            package_name="$(basename $redis_package)"
            if [[ -f linux/packages/${package_name} ]]; then
              tar jtvf packages/${package_name} > /dev/null 2>&1
              if [[ $? -gt 0 ]]; then
                  rm -f linux/packages/${package_name}
              fi
            fi

            if [[ ! -f linux/packages/${package_name} ]]; then
                wget -q -P linux/packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
                printf "$two_cols_table_format" "Redis package" "Downloaded"
            fi
        fi

        tar -xzvf ${redis_package} -C ${redis_install_path}
        cd ${redis_install_path}/${redis_version}
        make
        cd -

        cp -f ${redis_install_path}/${redis_version}/src/redis-server /usr/local/bin/
        cp -f ${redis_install_path}/${redis_version}/src/redis-cli /usr/local/bin/
        test ! -f /etc/redis/redis.conf || {
            mkdir -p /etc/redis/
            cp ${redis_install_path}/${redis_version}/redis.conf /etc/redis/
        }

        echo "redis-server -> /usr/local/bin/redis-server"
        echo "redis-cli -> /usr/local/bin/redis-cli"
        echo 
        echo "$ vim /etc/redis/redis.conf"

        echo "## redis" >> ~/.project_configuration
        echo ""       >> ~/.project_configuration
        echo "- path: ${redis_install_path}/${redis_version}" >> ~/.project_configuration
        echo "- server: /usr/local/bin/redis-server" >> ~/.project_configuration
        echo "- cli: /usr/local/bin/redis-cli" >> ~/.project_configuration
    ;;
    start|startup)
        printf "$two_cols_table_format" "redis" "Starting..."
        redis-server /etc/redis/redis.conf > /dev/null 2>&1
        printf "$two_cols_table_format" "redis" "Started"
    ;;
    status|state)
        pid=$(ps aux | grep redis | grep -v 'grep' | grep -v 'redis-tools' | awk '{print $2}' | xargs)
        if [[ -n "${pid}" ]]; then
            printf "$two_cols_table_format" "redis" "${pid}"
            exit 0
        fi
        printf "$two_cols_table_format" "redis" "Process Not Found"
        exit 1
    ;;
    monitor)
        bash $0 status
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "redis" "Process Not Found"
            printf "$two_cols_table_format" "redis" "Starting..."
            bash $0 start
        fi
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 check"
        logger "    $0 install"
        logger "    $0 start"
        logger "    $0 monitor"
        logger "    $0 check"
    ;;
esac