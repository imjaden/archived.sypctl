#!/usr/bin/env bash
#
########################################
#  
#  Nginx Tool
#
########################################

source linux/bash/common.sh

option="${2:-use-header}"

case "$1" in
    check)
        command -v nginx >/dev/null 2>&1 && fun_prompt_nginx_already_installed || {
            echo "warning: nginx command not found"
            exit 2
        }
    ;;
    install|deploy)
        command -v nginx >/dev/null 2>&1 && {
            fun_prompt_nginx_already_installed
            exit 1
        }

        case "${os_platform}" in
            CentOS6)
                sudo yum install -y readline-devel gcc-c++
                sudo rpm -ivh http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
                sudo yum -y install nginx
            ;;
            CentOS7)
                sudo yum install -y readline-devel gcc-c++ openssl-devel
                sudo rpm -Uvh http://nginx.org/packages/rhel/7/x86_64/RPMS/nginx-1.12.2-1.el7_4.ngx.x86_64.rpm
                sudo yum -y install nginx
            ;;
            Ubuntu16)  
                nginx_package=linux/packages/nginx-1.11.3.tar.gz
                nginx_install_path=/usr/local/src
                nginx_version=nginx-1.11.3

                if [[ -d ${nginx_install_path}/${nginx_version} ]]; then
                    rm -fr ${nginx_install_path}/${nginx_version} 
                    printf "$two_cols_table_format" "nginx package" "Removed Useless Package"
                fi

                if [[ ! -f ${nginx_package} ]]; then
                    printf "$two_cols_table_format" "nginx package" "Not Found"
                    printf "$two_cols_table_format" "nginx package" "Downloading..."

                    mkdir -p linux/packages
                    package_name="$(basename $nginx_package)"
                    if [[ -f linux/packages/${package_name} ]]; then
                      tar jtvf packages/${package_name} > /dev/null 2>&1
                      if [[ $? -gt 0 ]]; then
                          rm -f linux/packages/${package_name}
                      fi
                    fi

                    if [[ ! -f linux/packages/${package_name} ]]; then
                        wget -q -P linux/packages/ "http://qiniu-cdn.sypctl.com/${package_name}"
                        printf "$two_cols_table_format" "nginx package" "Downloaded"
                    fi
                fi

                tar -xzvf ${nginx_package} -C ${nginx_install_path}

                mv ${nginx_install_path}/${nginx_version} ${nginx_install_path}/nginx
                cd ${nginx_install_path}/nginx
                sudo ./configure --prefix=/usr/local/nginx --sbin-path=/usr/sbin/nginx --with-http_stub_status_module --with-http_ssl_module
                sudo make
                sudo make install
                sudo cp /usr/local/nginx/sbin/nginx /usr/bin/
                cd -
                
                test ! -f /etc/nginx/nginx.conf || {
                    mkdir -p /etc/nginx/
                    cp ${nginx_install_path}/nginx/nginx.conf /etc/nginx/
                }
            ;;
            *)
                echo "Nginx 安装工具暂不支持该系统：${os_platform}"
            ;;
        esac

        nginx -V
    ;;
    start|startup)
        bash $0 check
        test $? -eq 0 && {
            nginx
            test $? -eq 0 && bash $0 monitor
        }
    ;;
    stop)
        ps aux | grep nginx | grep -v 'grep' | awk '{print $2}' | xargs kill -9
    ;;
    restart)
        bash $0 stop
        bash $0 start
    ;;
    status|state)
        if [[ -n "${NGINX_PID_PATH}" ]]; then
            if [[ -f ${NGINX_PID_PATH} ]]; then
                master_pid=$(cat ${NGINX_PID_PATH})
                ps -ax | awk '{print $1}' | grep -e "^${master_pid}$" > /dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    worker_pids=$(ps -o pid --no-headers --ppid ${master_pid} | xargs)
                        printf "$two_cols_table_format" "nginx" "*${master_pid}"
                    for worker_pid in ${worker_pids[@]}; do
                        printf "$two_cols_table_format" "nginx" "${worker_pid}"
                    done
                    exit 0
                else
                    printf "$two_cols_table_format" "nginx" "-"
                    exit 1
                fi
            fi 
        else
            master_pid=$(ps aux | grep nginx | grep master | grep -v 'grep' | grep -v 'nginx-tools' | awk '{print $2}' | xargs)
            if [[ -n "${master_pid}" ]]; then
                worker_pids=$(ps -o pid --no-headers --ppid ${master_pid} | xargs)
                printf "$two_cols_table_format" "nginx" "*${master_pid}"
                for worker_pid in ${worker_pids[@]}; do
                    printf "$two_cols_table_format" "nginx" "${worker_pid}"
                done
                exit 0
            fi
        fi
        exit 1
    ;;
    monitor)
        bash $0 status ${option}
        if [[ $? -gt 0 ]]; then
            printf "$two_cols_table_format" "nginx" "Process Not Found"
            printf "$two_cols_table_format" "nginx" "Starting..."
            bash $0 start
        fi
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 check"
        logger "    $0 install"
        logger "    $0 start"
        logger "    $0 monitor"
    ;;
esac
