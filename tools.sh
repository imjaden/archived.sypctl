#!/usr/bin/env bash

title() {
    echo
    echo "$1"
    echo
}
function fun_deploy_file_folder() {
    folder_path="$1"
    test -d ${folder_path} && echo "${folder_path} already deployed!" || {
        mkdir -p ${folder_path}
        echo "${folder_path} deployed successfully"
    }
}

case "$1" in
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    install|deploy)
        title '## saas images'
        fun_deploy_file_folder /root/www/saas_images

        title '## saas backups'
        fun_deploy_file_folder /root/www/saas_backups

        title '## archive toolkit'
        bash lib/bash/archive-tools.sh check

        title '## deploy jdk'
        bash lib/bash/jdk-tools.sh install

        title '## deploy tomcat'
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAPI        install 8081
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatSuperAdmin install 8082
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin      install 8083

        title '## deploy zookeeper'
        bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper install

        title '## deploy service'
        bash lib/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar install
    ;;
    start|stop|status|restart|monitor)
        bash lib/bash/tomcat-tools.sh    /usr/local/src/tomcatAPI        $1
        bash lib/bash/tomcat-tools.sh    /usr/local/src/tomcatAdmin      $1
        bash lib/bash/tomcat-tools.sh    /usr/local/src/tomcatSuperAdmin $1
        bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper        $1
        bash lib/bash/nginx-tools.sh                                     $1
    ;;
    *)
        echo "warning: unkown params - $@"
    ;;
esac