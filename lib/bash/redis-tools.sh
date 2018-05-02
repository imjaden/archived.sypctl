#!/usr/bin/env bash
#
########################################
#  
#  Redis Installer
#
########################################

source lib/bash/common.sh

case "$1" in
    check)
        command -v redis-cli >/dev/null 2>&1 && fun_prompt_redis_already_installed || echo "warning: redis-cli command not found"
    ;;
    install|deploy)
        command -v redis-cli >/dev/null 2>&1 && {
            fun_prompt_redis_already_installed
            exit 1
        }

        redis_package=packages/redis-stable.tar.gz
        redis_install_path=/usr/local/src
        redis_version=redis-stable

        if [[ ! -f ${redis_package} ]]; then
            printf "$two_cols_table_format" "redis" "Tar Package Not Found"
            exit 2
        fi

        if [[ -d ${redis_install_path}/${redis_version} ]]; then
            printf "$two_cols_table_format" "redis" "Error: Deployed"
        fi

        tar -xzvf ${redis_package} -C ${redis_install_path}
        cd ${redis_install_path}/${redis_version}
        make
        cd -

        cp ${redis_install_path}/${redis_version}/src/redis-server /usr/local/bin/
        cp ${redis_install_path}/${redis_version}/src/redis-cli /usr/local/bin/
        mkdir -p /etc/redis/
        cp ${redis_install_path}/${redis_version}/redis.conf /etc/redis/

        echo "redis-server -> /usr/local/bin/redis-server"
        echo "redis-cli -> /usr/local/bin/redis-cli"
        echo 
        echo "vim /etc/redis/redis.conf"

        echo "## redis" >> ~/.project_configuration
        echo ""       >> ~/.project_configuration
        echo "- path: ${redis_install_path}/${redis_version}" >> ~/.project_configuration
        echo "- server: /usr/local/bin/redis-server" >> ~/.project_configuration
        echo "- cli: /usr/local/bin/redis-cli" >> ~/.project_configuration
    ;;
    start|startup)
        redis-server /etc/redis/redis.conf
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
