#!/usr/bin/env bash
#
########################################
#  
#  JDK Tool
#
########################################

source server/bash/common.sh

case "$1" in
    check)
        command -v java >/dev/null 2>&1 && fun_prompt_java_already_installed || echo "warning: java command not found"
    ;;
    install|deploy)
        command -v java >/dev/null 2>&1 && {
            fun_prompt_java_already_installed
            exit 1
        }

        jdk_package=server/packages/jdk-8u151-linux-x64.tar.gz
        jdk_install_path=/usr/local/src
        jdk_version=jdk1.8.0_151

        if [[ ! -f ${jdk_package} ]]; then
            printf "$two_cols_table_format" "JDK package" "Error: Not Found"
            printf "$two_cols_table_format" "JDK package" "Downloading..."

            mkdir -p server/packages
            package_name='jdk-8u151-linux-x64.tar.gz'
            if [[ -f server/packages/${package_name} ]]; then
              tar jtvf packages/${package_name} > /dev/null 2>&1
              if [[ $? -gt 0 ]]; then
                  rm -f server/packages/${package_name}
              fi
            fi

            if [[ ! -f server/packages/${package_name} ]]; then
                wget -q -P server/packages/ "http://7jpozz.com1.z0.glb.clouddn.com/${package_name}"
                printf "$two_cols_table_format" "JDK package" "Downloaded"
            fi
        fi

        if [[ -d ${jdk_install_path}/jdk ]]; then
            printf "$two_cols_table_format" "JDK folder" "Warning: Deployed"
            exit 2
        fi

        tar -xzvf ${jdk_package} -C ${jdk_install_path}
        mv ${jdk_install_path}/${jdk_version} ${jdk_install_path}/jdk

        echo "# jdk configuration" >> /etc/profile
        echo "export JAVA_HOME=${jdk_install_path}/jdk" >> /etc/profile
        echo "export JRE_HOME=${jdk_install_path}/jdk/jre" >> /etc/profile
        echo "export CLASS_PATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib" >> /etc/profile
        echo "export PATH=\$PATH:\$JAVA_PATH/bin:\$JRE_HOME/bin" >> /etc/profile

        echo "source /etc/profile" >> ~/.bash_profile

        source ~/.bash_profile

        java_bin_path=${jdk_install_path}/jdk/bin/java
        if [[ -f ${java_bin_path} ]]; then
          ln -sf ${jdk_install_path}/jdk/bin/java /usr/bin/java
        fi
            
        version=$(java -version)
        printf "$two_cols_table_format" "java" "${version:0:40}"

        echo "source ~/.bash_profile"
        echo "java -version"

        echo "## JDK" >> ~/.project_configuration
        echo ""       >> ~/.project_configuration
        echo "- path: ${jdk_install_path}/jdk" >> ~/.project_configuration
    ;;
    *)
        echo "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 start tomcat_home"
        logger "    $0 stop tomcat_home"
        logger "    $0 status|state tomcat_home"
        logger "    $0 monitor tomcat_home"
        logger "    $0 restart tomcat_home"
        logger "    $0 auto:generage:praams|agp tomcat_home"
    ;;
esac



