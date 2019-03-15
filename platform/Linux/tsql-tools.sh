#!/usr/bin/env bash
#
########################################
#  
#  MSSQL Client Tool
#
########################################
#
# referenced: https://www.microsoft.com/en-us/sql-server/developer-get-started/ruby/rhel/
#
source platform/Linux/common.sh

if [[ "${os_type}" != "CentOS" && "${os_type}" != "RedHatEnterpriseServer" ]]; then
    lsb_release -a
    echo "TSQL 脚本只适用于 CentOS/RedHatEnterpriseServer 系统，退出"
    exit 1
fi

function fun_install_gem_tiny_tds_or_not() {
    command -v gem > /dev/null 2>&1 && {
        install_state=$(gem list --local tiny_tds | grep tiny_tds | wc -l)
        [[ ${install_state} -eq 0 ]] && gem install tiny_tds

        gem list tiny_tds
    }
}

command -v tsql > /dev/null 2>&1 && {
    tsql -C
    fun_install_gem_tiny_tds_or_not

    sudo systemctl status mssql-server
    sudo systemctl stop mssql-server
    title "MSSQL 开发环境已部署！"
    exit 0
}

test -f /etc/yum.repos.d/mssql-server-2017.repo || {
    curl https://packages.microsoft.com/config/rhel/7/mssql-server-2017.repo | sudo tee /etc/yum.repos.d/mssql-server-2017.repo
}

yum info mssql-server || {
    sudo yum update -y
    sudo yum install -y mssql-server
    sudo /opt/mssql/bin/mssql-conf setup
}

test -d tmp/epel-release-latest-7.noarch.rpm || {
    cd tmp
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo rpm -ivh epel-release-latest-7.noarch.rpm
    sudo yum update
    sudo yum install -y git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel
    cd ..
}

command -v tsql > /dev/null 2>&1 && tsql -C || {
    cd tmp
    wget ftp://ftp.freetds.org/pub/freetds/stable/freetds-1.00.27.tar.gz
    tar -xzf freetds-1.00.27.tar.gz
    cd freetds-1.00.27
    sudo ./configure --prefix=/usr/local --with-tdsver=7.3
    sudo make
    sudo make install
    cd ..
}

fun_install_gem_tiny_tds_or_not

if [[ "${os_type}" = "CentOS" ]]; then
    sudo systemctl status mssql-server
    sudo systemctl stop mssql-server
elif [[ "${os_type}" = "Ubuntu" ]]; then
    echo "${os_platform} - TODO"
fi

tiny_tds_example=$(pwd)/config/tiny_tds.rb
test -f ${tiny_tds_example} && cat ${tiny_tds_example}
