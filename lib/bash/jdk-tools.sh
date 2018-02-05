#!/bin/bash
#
########################################
#  
#  JDK Installer
#
########################################

function fun_prompt_java_already_installed() {
    echo >&2 "java already installed!"
    echo
    echo "$ which java"
    which java
    echo
    echo "$ java -version"
    java -version
}

case "$1" in
    check)
        command -v java >/dev/null 2>&1 && fun_prompt_java_already_installed || echo "warning: java command not found"
    ;;
    install|deploy)
        command -v java >/dev/null 2>&1 && {
            fun_prompt_java_already_installed
            exit 1
        }

        jdk_package=packages/jdk-8u151-linux-x64.tar.gz
        jdk_install_path=/usr/local/src
        jdk_version=jdk1.8.0_151

        if [[ ! -f ${jdk_package} ]]; then
          echo "error: jdk package not found -${jdk_package}"; exit 2;
        fi

        if [[ -d ${jdk_install_path}/jdk ]]; then
          echo "error: jdk has already deployed - ${jdk_install_path}/jdk"; exit 2;
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
        java -version

        echo "source ~/.bash_profile"
        echo "java -version"

        echo "## jdk" >> ~/.project_configuration
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



