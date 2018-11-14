#!/usr/bin/env bash
#
########################################
#  
#  Redis Install Manager
#
########################################
#
# 参数说明:
#
# @operate   必填，Redis 安装操作
# @format    选填，操作日志的输出格式
#
# 完整示例：
#
# ```
# sypctl toolkit redis install
# # sypctl 内部格式输出时使用 format: table 
# sypctl toolkit redis install table 
# ```

source linux/bash/common.sh

format=${2:-custom}
case "$1" in
    check)
        command -v redis-cli >/dev/null 2>&1 && fun_prompt_redis_already_installed ${format} || echo "warning: redis-cli command not found"
    ;;
    install:force)
        redis_package=linux/packages/redis-stable.tar.gz
        redis_install_path=/usr/local/src
        redis_version=redis-stable
        package_name="$(basename $redis_package)"

        if [[ -d ${redis_install_path}/${redis_version} ]]; then
            rm -fr ${redis_install_path}/${redis_version} 
            printf "$two_cols_table_format" "Redis package" "Removed Useless Package"
        fi

        # 校正 tar.gz 文件的完整性(是否可以正常解压)
        # 不完整则删除
        if [[ -f ${redis_package} ]]; then
          tar jtvf ${redis_package} > /dev/null 2>&1
          [[ $? -gt 0 ]] && rm -f ${redis_package}
        fi

        # 不存在则下载
        if [[ ! -f ${redis_package} ]]; then
            if [[ "${format}" = "table" ]]; then
                printf "$two_cols_table_format" "Redis package" "not exist"
                printf "$two_cols_table_format" "Redis package" "downloading..."
            else
                echo "downloading ${package_name}..."
            fi

            mkdir -p linux/packages
            wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
            [[ "${format}" = "table" ]] && printf "$two_cols_table_format" "Redis package" "downloaded" || echo "downloaded ${package_name}"
        fi
    
        # 安装包不存在（说明下载失败）则退出 
        if [[ ! -f ${redis_package} ]]; then
            [[ "${format}" = "table" ]] && printf "$two_cols_table_format" "Redis package" "download failed" || echo "download ${package_name} failed then exit"
            exit 2
        fi

        tar -xzvf ${redis_package} -C ${redis_install_path}
        cd ${redis_install_path}/${redis_version}
        make
        cd -

        ln -snf ${redis_install_path}/${redis_version}/src/redis-server /usr/local/bin/redis-server
        cp -f ${redis_install_path}/${redis_version}/src/redis-cli /usr/local/bin/redis-cli
        test -f /etc/redis/redis.conf || {
            mkdir -p /etc/redis/
            cp ${redis_install_path}/${redis_version}/redis.conf /etc/redis/
        }

        version=$(redis-cli --version | awk '{ print $2 }')
        if [[ ${format} = "table" ]]; then
            printf "$two_cols_table_format" "redis" "${version:0:40}"
        else
            fun_prompt_redis_already_installed "custom"
        fi
    ;;
    install|deploy)
        command -v redis-cli >/dev/null 2>&1 && {
            fun_prompt_redis_already_installed ${format}
            exit 1
        }

        bash $0 install:force
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
        logger "\$ sypctl toolkit redis check"
        logger "\$ sypctl toolkit redis install"
    ;;
esac
