#!/bin/bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

current_user=$(whoami)
current_group=$(groups ${current_user} | awk '{ print $1 }')
if id -u sy-devops-user >/dev/null 2>&1; then
    if [[ "${current_user}" != "sy-devops-user" ]]; then\
        echo "Error: 请使用账号 sy-devops-user 执行!"
        exit 1
    fi
else
    echo "Error: 请添加用户 sy-devops-user"
    exit 1
fi

export LANG=zh_CN.UTF-8

function title() { printf "########################################\n# %s\n########################################\n" "$1"; }
SYPCTL_EXECUTE_PATH="$(pwd)"
SYPCTL_BRANCH=dev-0.1-master
SYPCTL_PREFIX=/usr/local/src
SYPCTL_HOME=${SYPCTL_PREFIX}/sypctl
SYPCTL_BIN=${SYPCTL_HOME}/bin

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
    packages[16]=jq
    packages[17]=openssl-devel
    packages[18]=readline-devel
    packages[19]=iptables-services
    packages[20]=libxslt-devel.x86_64
    packages[21]=libxml2-devel.x86_64
    packages[22]=yum-plugin-downloadonly
    packages[23]=redhat-lsb
    packages[24]=mysql-devel
    packages[25]=mysql
    packages[26]=lsof
    packages[27]=expect
    sudo yum install -y ${packages[@]}
}

test -d ${SYPCTL_HOME} || {
    sudo mkdir -p ${SYPCTL_HOME}
    sudo chown -R ${current_user}:${current_group} ${SYPCTL_HOME}
    sudo chmod -R ug+rwx ${SYPCTL_HOME}
    title "安装 sypctl..."
    git clone --branch ${SYPCTL_BRANCH} --depth 1 http://gitlab.ibi.ren/syp-apps/sypctl.git ${SYPCTL_HOME}
}

cd ${SYPCTL_HOME}
current_branch=$(git rev-parse --abbrev-ref HEAD)
[[ "${current_branch}" != "${SYPCTL_BRANCH}" ]] && {
    git reset --hard HEAD
    git fetch origin "${SYPCTL_BRANCH}":"${SYPCTL_BRANCH}"
    git checkout "${SYPCTL_BRANCH}"
}

local_modified=$(git status -s)
if [[ ! -z "${local_modified}" ]]; then
    git status
    read -p "本地代码有修改，可能会产生冲突，是否继续？y/n " user_input
    if [[ "${user_input}" != "y" ]]; then
        echo "退出操作！"
        exit 2
    fi
fi

git reset --hard HEAD
git pull origin ${SYPCTL_BRANCH} > /dev/null 2>&1
sudo chown -R ${current_user}:${current_group} ${SYPCTL_HOME}
sudo chmod -R ugo+rw ${SYPCTL_HOME}
sudo chmod -R ugo+x ${SYPCTL_HOME}/bin/

# force relink /usr/local/bin/
sypctl_commands=(sypctl syps sypt sypetl sypetlcheck)
for sypctl_command in ${sypctl_commands[@]}; do
    command -v ${sypctl_command} > /dev/null 2>&1 && sudo rm -f $(which ${sypctl_command})
    sudo ln -snf ${SYPCTL_HOME}/bin/${sypctl_command}.sh /usr/local/bin/${sypctl_command}
done

[[ "${PATH}" =~ "/usr/local/bin" ]] || {
    sudo chmod o+w /etc/profile
    sudo echo 'export PATH="/usr/local/bin:\$PATH"' >> /etc/profile
    source /etc/profile
}
source platform/middleware.sh > /dev/null 2>&1

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

    gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
    gem install bundle
    bundle config mirror.https://rubygems.org https://gems.ruby-china.com
    bundle config build.nokogiri --use-system-libraries

    ruby -v
    bundler -v
}

title "配置代理环境变量 env-files"
echo "${current_user}:${current_group}" > .installer
fun_sypctl_update_env_files

command -v rbenv >/dev/null 2>&1 && { rbenv -v; type rbenv; } || { 
    title "安装 Rbenv..."
    git clone --depth 1 git://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone --depth 1 git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    git clone --depth 1 git://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
    git clone --depth 1 https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
    git clone --depth 1 https://github.com/andorchen/rbenv-china-mirror.git ~/.rbenv/plugins/rbenv-china-mirror

    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ${SHELL_PROFILE}
    echo 'eval "$(rbenv init -)"' >> ${SHELL_PROFILE}

    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"

    type rbenv
    fun_rbenv_install_ruby
}

title "升级 Rbenv..."
rbenv_version=$(rbenv -v | cut -d ' ' -f 2)
cd ~/.rbenv
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

title "创建工作目录"
mkdir -p /data/{ftp,backup,work/{www,tools,scripts,config,logs}}

cat <<-EOF
目录约定:
- Web: /data/work/www
- 脚本: /data/work/scripts
- 工具: /data/work/tools
- 日志: /data/work/logs
- 配置档: /data/work/config
EOF