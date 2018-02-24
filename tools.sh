#!/usr/bin/env bash

source lib/bash/common.sh

case "$1" in
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    install|deploy)
        title '## .saarc '
        test -f .saasrc && echo '.saasrc already deployed!' || {
            cp lib/config/saasrc .saasrc
            echo '.saasrc deployed successfully'
        }

        title '## saas images'
        fun_deploy_file_folder /root/www/saas_images

        title '## saas backups'
        fun_deploy_file_folder /root/www/saas_backups

        title '## report'
        fun_deploy_file_folder /usr/local/src/report
        test -f /usr/local/src/report/index.html || {
            cp lib/config/index@report.html /usr/local/src/report
        }

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

        bash lib/bash/packages-tools.sh state
    ;;
    check)
        status_titles=(Service Status Comment)
        status_header="\n %-20s %-10s %-30s\n"
        status_format=" %-20s %-10s %-30s\n"
        printf "${status_header}" ${status_titles[@]}
        printf "%${status_width}.${status_width}s\n" "${status_divider}"

        printf "${status_format}" jdk $(command -v java >/dev/null 2>&1 && echo "true" || echo "false") /usr/local/src/jdk
        printf "${status_format}" report $(test -f /usr/local/src/report/index.html && echo "true" || echo "false") /usr/local/src/report/index.html
        printf "${status_format}" saas_images $(test -d /root/www/saas_images && echo "true" || echo "false") /root/www/saas_images
        printf "${status_format}" saas_backups $(test -d /root/www/saas_backups && echo "true" || echo "false") /root/www/saas_backups
        printf "${status_format}" zookeeper $(test -d /usr/local/src/zookeeper && echo "true" || echo "false") /usr/local/src/zookeeper
        printf "${status_format}" tomcatAPI $(test -d /usr/local/src/tomcatAPI && echo "true" || echo "false") /usr/local/src/tomcatAPI
        printf "${status_format}" providerAPI $(test -f /usr/local/src/providerAPI/api-service.jar && echo "true" || echo "false") /usr/local/src/providerAPI/api-service.jar
        printf "${status_format}" tomcatSuperAdmin $(test -d /usr/local/src/tomcatSuperAdmin && echo "true" || echo "false") /usr/local/src/tomcatSuperAdmin
        printf "${status_format}" tomcatAdmin $(test -d /usr/local/src/tomcatAdmin && echo "true" || echo "false") /usr/local/src/tomcatAdmin

        fun_printf_timestamp
    ;;
    start|stop|status|restart|monitor)
        if [[ "$1" = "status" || "$1" = "monitor" ]]; then
            printf "${status_header}" ${status_titles[@]}
            printf "%${status_width}.${status_width}s\n" "${status_divider}"
        fi

        bash lib/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar $1 "no-header"
        bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatAPI        $1 "no-header"
        bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatAdmin      $1 "no-header"
        bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatSuperAdmin $1 "no-header"
        bash lib/bash/zookeeper-tools.sh   /usr/local/src/zookeeper        $1 "no-header"
        bash lib/bash/nginx-tools.sh                                       $1 "no-header"
    ;;
    *)
        echo "warning: unkown params - $@"
    ;;
esac