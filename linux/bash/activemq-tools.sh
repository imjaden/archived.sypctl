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

activemq_home="${1:-$ACTIVEMQ_HOME}"
cmd_type="${2:-install}"
option="${3:-use-header}"
case "${cmd_type}" in
    install)
        if [[ -d ${activemq_home} ]]; then
            printf "$two_cols_table_format" "${activemq_home}" "deployed"
            exit 2
        fi

        activemq_package=linux/packages/apache-activemq-5.15.5.tar.gz
        activemq_version=apache-activemq-5.15.5

        if [[ ! -d ~/tools/${activemq_version} ]]; then
            test -d ~/tools || mkdir -p ~/tools
            if [[ ! -f ${activemq_package} ]]; then
                printf "$two_cols_table_format" "activemq package" "not exist"
                printf "$two_cols_table_format" "activemq package" "downloading..."

                mkdir -p linux/packages
                package_name="$(basename $activemq_package)"
                if [[ -f linux/packages/${package_name} ]]; then
                  tar jtvf packages/${package_name} > /dev/null 2>&1
                  if [[ $? -gt 0 ]]; then
                      rm -f linux/packages/${package_name}
                  fi
                fi

                if [[ ! -f linux/packages/${package_name} ]]; then
                    wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                    printf "$two_cols_table_format" "activemq package" "downloaded"
                fi
            fi
            
            tar -xzvf ${activemq_package} -C ~/tools
        fi

        cp linux/config/setting-${activemq_port}.xml ~/tools/${activemq_version}/conf/server.xml
        cp -r ~/tools/${activemq_version} ${activemq_home}

        printf "$two_cols_table_format" "${activemq_home}" "deployed successfully"
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 activemq_home install"
    ;;
esac