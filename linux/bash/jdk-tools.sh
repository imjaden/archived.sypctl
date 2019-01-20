#!/usr/bin/env bash
#
########################################
#  
#  JDK Install Manager
#
########################################
#
# 参数说明:
#
# @operate   必填，JDK 安装操作
# @format    选填，操作日志的输出格式
#
# 完整示例：
#
# ```
# sypctl toolkit jdk install:jdk
# # sypctl 内部格式输出时使用 format: table 
# sypctl toolkit jdk install:jdk table 
# ```

source linux/bash/common.sh

format=${2:-custom}
case "$1" in
    check)
        command -v javac >/dev/null 2>&1 && fun_prompt_javac_already_installed ${format} || echo "warning: javac command not found"
        command -v java >/dev/null 2>&1 && fun_prompt_java_already_installed ${format} || echo "warning: java command not found"
    ;;
    install:javac)
        command -v javac >/dev/null 2>&1 && {
            fun_prompt_javac_already_installed ${format} 
            exit 1
        }

        case "${os_platform}" in
            CentOS6)
                sudo yum install -y java-devel
            ;;
            CentOS7)
                sudo yum install -y java-devel
            ;;
            Ubuntu16)
                echo "not support this system($os_platform)"
            ;;
            *)
                echo "unknown system($os_platform)"
            ;;
        esac
    ;;
    install:jdk)
        command -v java >/dev/null 2>&1 && {
            fun_prompt_java_already_installed ${format} 
            exit 1
        }

        bash $0 install:jdk:force
    ;;
    jdk:install:force)
        jdk_package=linux/packages/jdk-8u192-linux-x64.tar.gz
        jdk_install_path=/usr/local/src
        jdk_version=jdk1.8.0_192
        package_name="$(basename $jdk_package)"

        # 校正 tar.gz 文件的完整性(是否可以正常解压)
        # 不完整则删除
        if [[ -f ${jdk_package} ]]; then
          tar jtvf ${jdk_package} > /dev/null 2>&1
          [[ $? -gt 0 ]] && rm -f ${jdk_package}
        fi

        # 不存在则下载
        if [[ ! -f ${jdk_package} ]]; then
            if [[ "${format}" = "table" ]]; then
                printf "$two_cols_table_format" "JDK package" "not exist"
                printf "$two_cols_table_format" "JDK package" "downloading..."
            else
                echo "downloading ${package_name}..."
            fi

            mkdir -p linux/packages
            wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
            [[ "${format}" = "table" ]] && printf "$two_cols_table_format" "JDK package" "downloaded" || echo "downloaded ${package_name}"
        fi

        # 安装包不存在（说明下载失败）则退出 
        if [[ ! -f ${jdk_package} ]]; then
            [[ "${format}" = "table" ]] && printf "$two_cols_table_format" "JDK package" "download failed" || echo "download ${package_name} failed then exit"
            exit 2
        fi

        [[ -d ${jdk_install_path}/jdk ]] && rm -fr ${jdk_install_path}/jdk
        tar -xzvf ${jdk_package} -C ${jdk_install_path}
        mv ${jdk_install_path}/${jdk_version} ${jdk_install_path}/jdk
        ln -snf ${jdk_install_path}/jdk/bin/java /usr/bin/java

        echo "# jdk configuration" >> /etc/profile
        echo "export JAVA_HOME=${jdk_install_path}/jdk" >> /etc/profile
        echo "export JRE_HOME=${jdk_install_path}/jdk/jre" >> /etc/profile
        echo "export CLASS_PATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib" >> /etc/profile
        echo "export PATH=\$PATH:\$JAVA_PATH/bin:\$JRE_HOME/bin" >> /etc/profile

        echo "source /etc/profile" >> ~/.bash_profile
        source ~/.bash_profile
            
        version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        if [[ ${format} = "table" ]]; then
            printf "$two_cols_table_format" "java" "${version:0:40}"
        else
            echo "$ source ~/.bash_profile"
            echo "$ java -version"
            echo 
            fun_prompt_java_already_installed "custom"
        fi
    ;;
    *)
        echo "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "\$ sypctl toolkit jdk install:jdk"
        logger "\$ sypctl toolkit jdk install:javac"
        logger "\$ sypctl toolkit jdk install:jdk:force"
    ;;
esac



