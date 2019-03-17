#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

SYPCTL_BRANCH=dev-0.0.1
SYPCTL_PREFIX=${SYPCTL_PREFIX_CUSTOM:-/usr/local/src}
SYPCTL_HOME=${SYPCTL_PREFIX}/sypctl
test -f ~/.bash_profile && source ~/.bash_profile
function title() { printf "########################################\n# %s\n########################################\n" "$1"; }

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

function fun_install_dependent_packages() {
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
        sudo yum install -y ${packages[@]}
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
}

fun_install_dependent_packages

title "安装/更新 sypctl..."
sudo mkdir -p /usr/local/src
test -d ${SYPCTL_HOME} || {
    cd ${SYPCTL_PREFIX}
    sudo git clone --branch ${SYPCTL_BRANCH} --depth 1 http://gitlab.ibi.ren/syp-apps/sypctl.git
}

if [[ "$(whoami)" != "root" ]]; then
    current_user=$(whoami)
    sudo chown -R ${current_user}:${current_user} ${SYPCTL_HOME}
fi

cd ${SYPCTL_HOME}
git pull origin ${SYPCTL_BRANCH} > /dev/null 2>&1

sudo ln -snf ${SYPCTL_HOME}/sypctl.sh /usr/bin/sypctl
sudo ln -snf ${SYPCTL_HOME}/bin/syps.sh /usr/bin/syps
sudo ln -snf ${SYPCTL_HOME}/bin/sypt.sh /usr/bin/sypt

title "检查/安装 JDK..."
command -v java > /dev/null || bash platform/Linux/jdk-tools.sh install:jdk
command -v javac > /dev/null || bash platform/Linux/jdk-tools.sh install:javac

title "检查/安装 Rbenv/Ruby..."
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
mkdir -p {monitor/{index,pages},logs,tmp/pids,db}
bundle install > /dev/null 2>&1
cd ..

title "已安装软件清单..."
custom_col1_width=22
custom_col2_width=32
source platform/Linux/common.sh

fun_print_table_header "Installed State" "Component" "Version"
dependency_commands=(git rbenv ruby gem bundle)
for cmd in ${dependency_commands[@]}; do
    version=$(${cmd} --version)
    printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
done
fun_prompt_java_already_installed
fun_print_table_footer

title "sypctl 约束配置..."
sypctl ssh-keygen

title "sypctl 基础服务配置..."
sypctl toolkit date check
sypctl schedule:update
sypctl schedule:jobs

title "sypctl 安装完成"
sypctl help
