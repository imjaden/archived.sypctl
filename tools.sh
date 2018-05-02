#!/usr/bin/env bash

source lib/bash/common.sh

case "$1" in
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    install|deploy|check)
        mkdir -p ./logs
        bash lib/bash/packages-tools.sh state
        fun_print_table_header "Components State" "Component" "DeployedState"

        test -f .env-files && printf "$two_cols_table_format" ".env-files" "Deployed" || {
            cp lib/config/saasrc .env-files
            printf "$two_cols_table_format" ".env-files" "Deployed Successfully"
        }

        check_install_defenders_include "SaaSImage" && {
            fun_deploy_file_folder ~/www/saas_images
        }

        check_install_defenders_include "SaaSBackup" && {
            fun_deploy_file_folder ~/www/saas_backups
        }

        check_install_defenders_include "Report" && {
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

        # check_install_defenders_include "ZipRaR" && {
        #     bash lib/bash/archive-tools.sh check
        # }

        check_install_defenders_include "JDK" && {
            bash lib/bash/jdk-tools.sh install
        }

        check_install_defenders_include "SYPAPI" && {
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAPI        install 8081
            bash lib/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar install
        }

        check_install_defenders_include "SYPSuperAdmin" && {
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatSuperAdmin install 8082
        }

        check_install_defenders_include "SYPAdmin" && {
            bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin      install 8083
        }

        check_install_defenders_include "Zookeeper" && {
            bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper install
        }

        check_install_defenders_include "Redis" && {
            bash lib/bash/redis-tools.sh install
        }
        fun_print_table_footer
    ;;
    start|stop|status|restart|monitor)
        fun_print_table_header "Components Process State" "Component" "ProcessId"

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

        fun_print_table_footer
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