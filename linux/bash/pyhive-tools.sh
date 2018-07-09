#!/usr/bin/env bash
#
########################################
#  
#  PHive Tool
#  https://github.com/dropbox/PyHive
#  https://blog.csdn.net/wulantian/article/details/74330590
#
########################################

command -v pip > /dev/null || {
    sudo curl https://bootstrap.pypa.io/get-pip.py > get-pip.py
    sudo python get-pip.py
}

sudo yum install -y gcc-c++ python-devel.x86_64 cyrus-sasl-devel.x86_64

sudo pip install sasl thrift thrift-sasl sqlalchemy
sudo pip install pyhive[hive]
sudo pip install pyhive[presto]
