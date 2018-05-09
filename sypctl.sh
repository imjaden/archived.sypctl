#!/usr/bin/env bash

source server/bash/common.sh
current_path="$(pwd)"
# cd /opt/scripts/syp-saas-scripts

case "$1" in
    git:pull|gp)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;
    install|deploy|check)
        mkdir -p ./logs
        bash server/bash/packages-tools.sh state
        fun_print_table_header "Components State" "Component" "DeployedState"

        test -f .env-files && printf "$two_cols_table_format" ".env-files" "Deployed" || {
            cp server/config/saasrc .env-files
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
            cp server/config/index@report.html syp-saas-tutorial.html
            sed -i "s/VAR_SHORTCUT/${var_shortcut}/g" syp-saas-tutorial.html
            sed -i "s/VAR_SLOGAN/${var_slogan}/g" syp-saas-tutorial.html
            test -f /usr/local/src/report/index.html || {
                cp syp-saas-tutorial.html /usr/local/src/report/index.html
            }
            mv syp-saas-tutorial.html ~/www/syp-saas-tutorial.html
        }

        # check_install_defenders_include "ZipRaR" && {
        #     bash server/bash/archive-tools.sh check
        # }

        check_install_defenders_include "JDK" && {
            bash server/bash/jdk-tools.sh install
        }

        check_install_defenders_include "SYPAPI" && {
            bash server/bash/tomcat-tools.sh /usr/local/src/tomcatAPI        install 8081
            bash server/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar install
        }

        check_install_defenders_include "SYPSuperAdmin" && {
            bash server/bash/tomcat-tools.sh /usr/local/src/tomcatSuperAdmin install 8082
        }

        check_install_defenders_include "SYPAdmin" && {
            bash server/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin      install 8083
        }

        check_install_defenders_include "Zookeeper" && {
            bash server/bash/zookeeper-tools.sh /usr/local/src/zookeeper install
        }

        check_install_defenders_include "Redis" && {
            bash server/bash/redis-tools.sh install
        }
        fun_print_table_footer
    ;;
    start|stop|status|restart|monitor)
        fun_print_table_header "Components Process State" "Component" "ProcessId"

        check_install_defenders_include "Redis" && {
            bash server/bash/redis-tools.sh $1 "no-header"
        }

        check_install_defenders_include "Zookeeper" && {
            bash server/bash/zookeeper-tools.sh /usr/local/src/zookeeper $1 "no-header"
        }

        check_install_defenders_include "SYPAPI" && {
            bash server/bash/jar-service-tools.sh /usr/local/src/providerAPI/api-service.jar $1 "no-header"
            bash server/bash/tomcat-tools.sh      /usr/local/src/tomcatAPI        $1 "no-header"
        }

        check_install_defenders_include "SYPSuperAdmin" && {
            bash server/bash/tomcat-tools.sh      /usr/local/src/tomcatSuperAdmin $1 "no-header"
        }

        check_install_defenders_include "SYPAdmin" && {
            bash server/bash/tomcat-tools.sh      /usr/local/src/tomcatAdmin      $1 "no-header"
        }
        check_install_defenders_include "Nginx" && {
            bash server/bash/nginx-tools.sh $1 "no-header"
        }

        fun_print_table_footer
    ;;
    package:status|ps)
        bash server/bash/packages-tools.sh state
    ;;
    guide|install:help|ih)
        fun_user_expect_to_install_package_guides
    ;;
    apk)
        bash android/tools.sh assemble "$2"
    ;;
    shengyiplus|ruishangplus|yh_android|shenzhenpoly)
        bash ios/tools.sh "$1"
    ;;
    *)
        echo ""
        echo "Usage: sypctl <command>"
        echo ""
        echo "sypctl help         sypctl 支持的命令参数列表，及已部署服务的信息"
        echo "sypctl deploy       部署服务引导，并安装部署输入 \`y\` 确认的服务"
        echo ""
        echo "sypctl monitor      已部署的服务进程状态，若未监测到进程则启动该服务"
        echo "sypctl start        启动已部署的服务进程"
        echo "sypctl status       已部署的服务进程状态"
        echo "sypctl restart      重启已部署的服务进程"
        echo "sypctl stop         关闭已部署的服务进程"
        echo ""
        echo "sypctl apk <app-name> 打包生意+ 安卓APK;支持的应用如下："
        echo "                      - 生意+ shengyiplus"
        echo "                      - 睿商+ ruishangplus"
        echo "                      - 永辉 yh_android"
        echo "                      - 保臻 shenzhenpoly"
        echo "sypctl <app-name>     切换生意+ iOS 不同项目的静态资源；应用名称同上"
        echo ""
        echo "sypctl git:pull     更新脚本代码"
        echo ""
    ;;
esac

cd ${current_path}