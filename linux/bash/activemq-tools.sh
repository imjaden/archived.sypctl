#!/usr/bin/env bash
#
########################################
#  
#  ActiveMQ Process Manager(War)
#
########################################
#
# 参数说明:(传参顺序必须一致)
#
# @activemq_home   activemq 部署路径，默认为 ACTIVEMQ_HOME
# @cmd_type        执行 activemq 的命令，支持 shutdown/startup/restartup, 默认 startup
#
# 完整示例：
#
# ```
# activemq_home="/usr/local/src/activeMQ"
# cmd_type="install"
#
# bash activemq-tools.sh "${activemq_home}" "${cmd_type}"
# ```

source linux/bash/common.sh

cmd_type="${1:-install}"
activemq_home="${2:-$ACTIVEMQ_HOME}"
option="${3:-use-header}"

case "${cmd_type}" in
    install)
        if [[ -d ${activemq_home} ]]; then
            printf "$two_cols_table_format" "${activemq_home}" "deployed"
            exit 2
        fi

        activemq_package=linux/packages/apache-activemq-5.15.5.tar.gz
        activemq_hash=1e907d255bc2b5761ebc0de53c538d8c
        activemq_version=apache-activemq-5.15.5

        if [[ ! -d ~/tools/${activemq_version} ]]; then
            test -d ~/tools || mkdir -p ~/tools
            if [[ ! -f ${activemq_package} ]]; then
                printf "$two_cols_table_format" "activemq package" "not exist"
                printf "$two_cols_table_format" "activemq package" "downloading..."

                mkdir -p linux/packages
                package_name="$(basename $activemq_package)"
                if [[ -f ${activemq_package} ]]; then
                    # @过期算法
                    # tar jtvf packages/${package_name} > /dev/null 2>&1
                    # if [[ $? -gt 0 ]]; then
                    #     rm -f linux/packages/${package_name}
                    # fi
                    #
                    # @手工校正文件哈希
                    current_hash=todo
                    command -v md5 > /dev/null && current_hash=$(md5 -q ${activemq_package})
                    command -v md5sum > /dev/null && current_hash=$(md5sum ${activemq_package} | cut -d ' ' -f 1)
                    test "${activemq_hash}" != "${current_hash}" && rm -f ${activemq_package}
                fi

                if [[ ! -f ${activemq_package} ]]; then
                    wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                    printf "$two_cols_table_format" "activemq package" "downloaded"
                fi
            fi
            
            tar -xzvf ${activemq_package} -C ~/tools
        fi

        cp -r ~/tools/${activemq_version} ${activemq_home}

        printf "$two_cols_table_format" "${activemq_home}" "deployed successfully"
    ;;
    install:force)
        [[ -d ${activemq_home} ]] && rm -fr ${activemq_home}
        sypctl toolkit activemq install ${activemq_home}
    ;;
    help)
        echo "activeMQ管理:"
        echo "sypctl toolkit activemq help"
        echo "sypctl toolkit activemq install <expect-to-install-path>"
        echo "sypctl toolkit activemq install:force <expect-to-install-path>"
    ;;
    *)
        echo "警告：未知参数 - $@"
        echo
        sypctl toolkit activemq help
    ;;
esac