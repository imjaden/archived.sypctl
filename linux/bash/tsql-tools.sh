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
source linux/bash/common.sh
tiny_tds_example=$(pwd)/linux/config/tiny_tds.rb

test -f /etc/yum.repos.d/mssql-server-2017.repo || {
    curl https://packages.microsoft.com/config/rhel/7/mssql-server-2017.repo | sudo tee /etc/yum.repos.d/mssql-server-2017.repo
}

command -v mssql-server > /dev/null 2>&1 || {
    sudo yum update
    sudo yum install mssql-server
    sudo /opt/mssql/bin/mssql-conf setup
}

mkdir -p ~/tools/
test -d ~/tools/epel-release-latest-7.noarch.rpm || {
    cd ~/tools/
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo rpm -ivh epel-release-latest-7.noarch.rpm
    sudo yum update
    sudo yum install -y git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel
}

command -v tsql > /dev/null 2>&1 || {
    cd ~/tools/
    wget ftp://ftp.freetds.org/pub/freetds/stable/freetds-1.00.27.tar.gz
    tar -xzf freetds-1.00.27.tar.gz
    cd freetds-1.00.27
    ./configure --prefix=/usr/local --with-tdsver=7.3
    make
    make install
}

command -v gem > /dev/null 2>&1 || {
    gem install tiny_tds
}

test -f ${tiny_tds_example} && cat ${tiny_tds_example}




