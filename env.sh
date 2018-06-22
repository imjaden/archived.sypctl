#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

SYPCTL_HOME=/usr/local/src/sypctl
test -f ~/.bash_profile && source ~/.bash_profile
function title() { printf "\n%s\n\n" "$1"; }

title "安装基础依赖的软件..."
function fun_install() {
    command -v yum > /dev/null && {
        title "\$ sudo yum install -y $1"
        sudo yum install -y "$1"
    }
    command -v apt-get > /dev/null && {
        title "\$ sudo apt-get install -y $1"
        sudo apt-get install -y "$1"
    } 
}

command -v lsb_release > /dev/null || fun_install redhat-lsb
lsb_release -a

supported_os_platforms=(RedHatEnterpriseServer6 RedHatEnterpriseServer7 CentOS6 CentOS7 Ubuntu16)
os_platform="UnknownOS"
os_type=$(lsb_release -i | awk '{ print $3 }')
os_version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
if [[ "${supported_os_platforms[@]}" =~ "${os_type}${os_version}" ]]; then
    os_platform="${os_type}${os_version}"
else
    os_platform=$(uname -s)
    echo "ERROR: unsupport system - ${os_platform}"
    exit 1
fi

command -v yum > /dev/null && {
    packages=(git rdate dos2unix vim-enhanced iptables-services net-tools wget bzip2 gcc gcc-c++ automake autoconf libtool make openssl openssl-devel readline-devel zlib-devel readline-devel libxslt-devel.x86_64 libxml2-devel.x86_64 tree)
    for package in ${packages[@]}; do
      rpm -q ${package} > /dev/null 2>&1 || {
          printf "installing ${package}..."
          sudo yum install -y ${package} > /dev/null 2>&1
          printf "$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')\n"
      }
    done
}

command -v apt-get > /dev/null && {
    packages=(git rdate git-core git-doc lsb-release curl libreadline-dev libcurl4-gnutls-dev libssl-dev libexpat1-dev gettext libz-dev tree language-pack-zh-hant language-pack-zh-hans)
    for package in ${packages[@]}; do
      command -v ${package} > /dev/null || {
          printf "installing ${package}..."
          sudo apt-get build-dep -y ${package} > /dev/null 2>&1
          sudo apt-get install -y ${package} > /dev/null 2>&1
          printf "$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')\n"
      }
    done
}

title "移除旧版本的 sypctl..."
# remove deprecated sypctl command
# -----------------------------------
test -f ~/.bash_profile && sed -i /sypctl/d ~/.bash_profile > /dev/null 2>&1
unalias sypctl > /dev/null 2>&1
# test -d /opt/scripts/syp-saas-scripts && sudo rm -fr /opt/scripts/syp-saas-scripts
# test -d /opt/scripts/sypctl && sudo rm -fr /opt/scripts/sypctl
# -----------------------------------

title "安装/更新 sypctl..."
sudo mkdir -p /usr/local/src
test -d ${SYPCTL_HOME} || {
    cd /usr/local/src
    sudo git clone --branch dev-0.0.1 --depth 1 http://gitlab.ibi.ren/syp-apps/sypctl.git
}

if [[ "$(whoami)" != "root" ]]; then
    current_user=$(whoami)
    sudo chown -R ${current_user}:${current_user} ${SYPCTL_HOME}
fi

cd ${SYPCTL_HOME}
git remote set-url origin http://gitlab.ibi.ren/syp-apps/sypctl.git
git pull origin dev-0.0.1 > /dev/null 2>&1

test -L /usr/bin/sypctl && sudo unlink /usr/bin/sypctl
sudo ln -s ${SYPCTL_HOME}/sypctl.sh /usr/bin/sypctl

title "检查/安装 JDK..."
command -v java > /dev/null || bash linux/bash/jdk-tools.sh install

title "检查/安装 Rbenv/Ruby..."
function fun_rbenv_install_ruby() {
    rbenv install --skip-existing 2.3.0 
    rbenv rehash
    rbenv global 2.3.0

    gem install bundle
    bundle config mirror.https://rubygems.org https://gems.ruby-china.org
    bundle config build.nokogiri --use-system-libraries

    ruby -v
    bundler -v
}

command -v rbenv >/dev/null 2>&1 && { rbenv -v; type rbenv; } || { 
    git clone --depth 1 git://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone --depth 1 git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    git clone --depth 1 git://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
    git clone --depth 1 https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
    git clone --depth 1 https://github.com/andorchen/rbenv-china-mirror.git ~/.rbenv/plugins/rbenv-china-mirror
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
    source ~/.bash_profile
    type rbenv

    fun_rbenv_install_ruby
}

command -v ruby >/dev/null 2>&1 && ruby -v || { 
    fun_rbenv_install_ruby
}

cd agent
mkdir -p {monitor/{index,pages},logs,tmp/pids,db,jobs}
bundle install > /dev/null 2>&1
cd ..

title "已安装软件清单..."
custom_col1_width=22
custom_col2_width=32
source linux/bash/common.sh

fun_print_table_header "Installed State" "Component" "Version"
dependency_commands=(git rbenv ruby gem bundle)
for cmd in ${dependency_commands[@]}; do
    version=$(${cmd} --version)
    printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
done
fun_prompt_java_already_installed
fun_print_table_footer

title "sypctl 约束配置..."
sypctl crontab
sypctl rc.local
sypctl ssh-keygen
sypctl linux:date check
sypctl help
sypctl home