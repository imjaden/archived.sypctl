#!/bin/bash

SYPCTL_EXECUTE_PATH="$(pwd)"
SYPCTL_BASH=$(readlink /usr/local/bin/sypctl)
SYPCTL_BIN=$(dirname ${SYPCTL_BASH})
SYPCTL_HOME=$(dirname ${SYPCTL_BIN})

cd ${SYPCTL_HOME}
source platform/middleware.sh

function help() {
  echo "操作示例:"
  echo
  echo "$ sypetl 公司名称 模块名称"
  echo "$ sypetlcheck 公司名称 模块名称"
  echo
  echo "脚本路径: /data/work/scripts/公司名称/模块名称/tools.sh"
  exit 1
}

test -z "$1" && help
test -z "$2" && help

ruby platform/ruby/sypetl-tools.rb --check --companyname "$1" --modulename "$2"