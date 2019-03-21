#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

SYPCTL_EXECUTE_PATH="$(pwd)"
test "$(uname -s)" = "Darwin" && SYPCTL_PREFIX=/usr/local/opt
test "$(uname -s)" = "Linux" && SYPCTL_PREFIX=/usr/local/src
SYPCTL_HOME=${SYPCTL_PREFIX}/sypctl
SYPCTL_BRANCH=dev-0.0.1
function title() { printf "########################################\n# %s\n########################################\n" "$1"; }

if [[ -z "${SYPCTL_PREFIX}" ]]; then
    title "执行预检: 暂未兼容该系统 - $(uname -s)"
    exit 1
fi

title "安装系统依赖..."
command -v yum > /dev/null && {
    declare -a packages
    packages[0]=git
    packages[1]=tree
    packages[2]=wget
    packages[3]=make
    packages[4]=rdate
    packages[5]=dos2unix
    packages[6]=net-tools
    packages[7]=bzip2
    packages[8]=gcc
    packages[9]=gcc-c++
    packages[10]=automake
    packages[11]=autoconf
    packages[12]=libtool
    packages[13]=openssl
    packages[14]=vim-enhanced
    packages[15]=zlib-devel
    packages[16]=mysql-devel
    packages[17]=openssl-devel
    packages[18]=readline-devel
    packages[19]=iptables-services
    packages[20]=libxslt-devel.x86_64
    packages[21]=libxml2-devel.x86_64
    packages[22]=yum-plugin-downloadonly
    packages[23]=redhat-lsb
    sudo yum install -y ${packages[@]}
}

if [[ "$(uname -s)" = "Darwin" ]]; then
    command -v brew > /dev/null || {
        title "安装 Homebrew"
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    }
    command -v greadlink > /dev/null || {
        title "安装 coreutils"
        brew install coreutils
    }
fi

command -v brew > /dev/null && {
    declare -a packages
    packages[0]=git
    packages[1]=tree
    packages[2]=wget
    packages[3]=curl
    packages[4]=openssl
    package_list=(git wget curl openssl)
    for package in ${package_list[@]}; do
        command -v ${package} > /dev/null 2>&1 || {
          title "安装 ${package}"
          brew install ${package}
        }
    done
}

test -d ${SYPCTL_HOME} || {
    mkdir -p ${SYPCTL_PREFIX}
    cd ${SYPCTL_PREFIX}
    title "安装 sypctl..."
    git clone --branch ${SYPCTL_BRANCH} --depth 1 http://gitlab.ibi.ren/syp-apps/sypctl.git

    if [[ "$(whoami)" != "root" ]]; then
        current_user=$(whoami)
        chown -R ${current_user}:${current_user} ${SYPCTL_HOME}
    fi
}

cd ${SYPCTL_HOME}
git pull origin ${SYPCTL_BRANCH} > /dev/null 2>&1
source platform/middleware.sh > /dev/null 2>&1

ln -snf ${SYPCTL_HOME}/sypctl.sh /usr/local/bin/sypctl
ln -snf ${SYPCTL_HOME}/bin/syps.sh /usr/local/bin/syps
ln -snf ${SYPCTL_HOME}/bin/sypt.sh /usr/local/bin/sypt

command -v java > /dev/null || {
    title "安装 JDK..."
    bash platform/$(uname -s)/jdk-tools.sh install:jdk
}
command -v javac > /dev/null || {
    title "安装 JAVAC..."
    bash platform/$(uname -s)/jdk-tools.sh install:javac
}

function fun_rbenv_install_ruby() {
    rbenv install --skip-existing 2.3.0 
    rbenv rehash
    rbenv global 2.3.0

    gem install bundle
    bundle config mirror.https://rubygems.org https://gems.ruby-china.com
    bundle config build.nokogiri --use-system-libraries

    ruby -v
    bundler -v
}

command -v rbenv >/dev/null 2>&1 && { rbenv -v; type rbenv; } || { 
    title "安装 Rbenv..."
    git clone --depth 1 git://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone --depth 1 git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    git clone --depth 1 git://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
    git clone --depth 1 https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
    git clone --depth 1 https://github.com/andorchen/rbenv-china-mirror.git ~/.rbenv/plugins/rbenv-china-mirror

    type rbenv
    eval "$(rbenv init -)"
    fun_rbenv_install_ruby
}

system_shell=${SHELL##*/}
shell_profile=
if [[ "${system_shell}" = "zsh" ]]; then
    shell_profile=~/.zshrc
elif [[ "${system_shell}" = "bash" ]] || [[ "${system_shell}" = "sh" ]]; then
    shell_profile=~/.bash_profile
else
    title "执行预检: 暂未兼容该SHEEL - ${system_shell}"
    exit 1
fi

echo "$(readlink ${shell_profile})" >> .env-files
cat .env-files | uniq > .env-files
if [[ $(grep "\$HOME/.rbenv/bin" ${shell_profile} | wc -l) -gt 0 ]]; then
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ${shell_profile}
    echo 'eval "$(rbenv init -)"' >> ${shell_profile}
    source ${shell_profile} > /dev/null 2>&1
fi

title "升级 Rbenv..."
cd ~/.rbenv
rbenv_version=$(rbenv -v | cut -d ' ' -f 2)
git pull > /dev/null 2>&1
echo "rbenv ${rbenv_version} => $(rbenv -v | cut -d ' ' -f 2)"
title "检测 Rbenv..."
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-doctor | bash

command -v ruby >/dev/null 2>&1 && ruby -v || { 
    title "安装 Ruby..."
    fun_rbenv_install_ruby
}

cd ${SYPCTL_HOME}
title "安装代理依赖..."
cd agent
mkdir -p {monitor/{index,pages},logs,tmp/pids,db,.config}
bundle install > /dev/null 2>&1
cd ..

title "配置 SSH Key..."
sypctl ssh:keygen > /dev/null 2>&1

title "配置基础服务..."
sypctl toolkit date check
sypctl schedule:update
sypctl schedule:jobs

title "安装列表清单"
custom_col1_width=22
custom_col2_width=32

fun_print_table_header "Installed State" "Component" "Version"
dependency_commands=(git rbenv ruby gem bundle)
for cmd in ${dependency_commands[@]}; do
    version=$(${cmd} --version)
    printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
done
fun_prompt_java_already_installed
fun_print_table_footer

title "sypctl 安装完成"

sypctl help
cd ${SYPCTL_EXECUTE_PATH}
