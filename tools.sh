#!/usr/bin/env bash

source lib/bash/common.sh

case "$1" in
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    install|deploy)
        mkdir -p ./logs
        
        title '## .env-files '
        test -f .env-files && echo '.env-files already deployed!' || {
            cp lib/config/saasrc .env-files
            echo '.env-files deployed successfully'
        }

        check_install_defenders_include "SaaSImage" && {
            title '## SaaSImage'
            fun_deploy_file_folder ~/www/saas_images
        }

        check_install_defenders_include "SaaSBackup" && {
            title '## SaaSBackup'
            fun_deploy_file_folder ~/www/saas_backups
        }


        check_install_defenders_include "Report" && {
            title '## Report'
            fun_deploy_file_folder /usr/local/src/report
            test -f .tutorial-conf.sh || {
                echo "var_shortcut='S'" > .tutorial-conf.sh
                echo "var_slogan='生意+ SaaS 系统服务引导页'" >> .tutorial-conf.sh
            }
            source .tutorial-conf.sh
            cp lib/config/index@report.html syp-saas-tutorial.html
            sed -i "s/VAR_SHORTCUT/${var_shortcut}/g" syp-saas-tutorial.html
            sed -i "s/VAR_SLOGAN/${var_slogan}/g" syp-saas-tutorial.html
            test -f /usr/local/src/report/index.html || {
                cp syp-saas-tutorial.html /usr/local/src/report/index.html
            }
            mv syp-saas-tutorial.html ~/www/syp-saas-tutorial.html
        }

        check_install_defenders_include "ZipRaR" && {
            title '## archive toolkit'
            bash lib/bash/archive-tools.sh check
        }

        check_install_defenders_include "JDK" && {
            title '## deploy jdk'
            bash lib/bash/jdk-tools.sh install
        }

        check_install_defenders_include "SYPAPI" && {
            title '## deploy SYPAPI'
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAPI        install 8081
            bash lib/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar install
        }

        check_install_defenders_include "SYPSuperAdmin" && {
            title '## deploy SYPSuperAdmin'
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatSuperAdmin install 8082
        }

        check_install_defenders_include "SYPAdmin" && {
            title '## deploy SYPAdmin'
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin      install 8083
        }

        check_install_defenders_include "Zookeeper" && {
            title '## deploy zookeeper'
            bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper install
        }

        check_install_defenders_include "Redis" && {
            title '## deploy redis'
            bash lib/bash/redis-tools.sh install
        }
    ;;
    check)
        status_titles=(Service Status Comment)
        status_header="\n %-20s %-10s %-30s\n"
        status_format=" %-20s %-10s %-30s\n"
        printf "${status_header}" ${status_titles[@]}
        printf "%${status_width}.${status_width}s\n" "${status_divider}"

        printf "${status_format}" jdk $(command -v java > /dev/null 2>&1 && echo "true" || echo "false") /usr/local/src/jdk
        printf "${status_format}" report $(test -f /usr/local/src/report/index.html && echo "true" || echo "false") /usr/local/src/report/index.html
        printf "${status_format}" saas_images $(test -d ~/www/saas_images && echo "true" || echo "false") ~/www/saas_images
        printf "${status_format}" saas_backups $(test -d ~/www/saas_backups && echo "true" || echo "false") ~/www/saas_backups
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

        check_install_defenders_include "SYPAPI" && {
            bash lib/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar $1 "no-header"
            bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatAPI        $1 "no-header"
        }

        check_install_defenders_include "SYPSuperAdmin" && {
            bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatSuperAdmin $1 "no-header"
        }

        check_install_defenders_include "SYPAdmin" && {
            bash lib/bash/tomcat-tools.sh      /usr/local/src/tomcatAdmin      $1 "no-header"
        }

        check_install_defenders_include "Zookeeper" && {
            bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper $1 "no-header"
        }

        check_install_defenders_include "Nginx" && {
            bash lib/bash/nginx-tools.sh $1 "no-header"
        }

        fun_printf_timestamp
    ;;
    package:status|ps)
        bash lib/bash/packages-tools.sh state
    ;;
    install:help|ih)
        fun_user_expect_to_install_package_guides
    ;;
    *)
        logger "warning: unkown params - $@"
        logger "Usage:"
        logger "    $0 git:pull"
        logger "    $0 install|deploy"
        logger "    $0 install:help"
        logger "    $0 check"
        logger "    $0 start|stop|status|restart|monitor"
    ;;
esac