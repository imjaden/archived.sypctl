#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

SYPCTL_HOME=/usr/local/opt/sypctl
function title() { printf "####################\n# %s\n####################\n" "$1"; }

command -v brew || {
  title "安装 Homebrew"

  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

package_list=(git wget curl)
for package in ${package_list[@]}; do
    command -v ${package} > /dev/null 2>&1 || {
      title "安装 ${package}"
      brew install ${package}
    }
done

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

# https://github.com/rbenv/rbenv#toc8
command -v rbenv > /dev/null 2>&1 || {
  title "安装 rbenv"
  brew install rbenv
  rbenv init
  curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-doctor | bash
  
  fun_rbenv_install_ruby
}

title "升级 rbenv"
brew upgrade rbenv ruby-build

command -v ruby >/dev/null 2>&1 && ruby -v || { 
    fun_rbenv_install_ruby
}

test -d ${SYPCTL_HOME} || {
    title "安装 sypctl"
    cd /usr/local/opt/
    git clone --branch dev-0.0.1 --depth 1 http://gitlab.ibi.ren/syp-apps/sypctl.git
}

title "更新 sypctl"
cd ${SYPCTL_HOME}
git pull origin dev-0.0.1 > /dev/null 2>&1

sudo ln -snf ${SYPCTL_HOME}/sypctl.sh /usr/local/bin/sypctl
sudo ln -snf ${SYPCTL_HOME}/bin/syps.sh /usr/local/bin/syps
sudo ln -snf ${SYPCTL_HOME}/bin/sypt.sh /usr/local/bin/sypt

cd agent
mkdir -p {monitor/{index,pages},logs,tmp/pids,db}
bundle install > /dev/null 2>&1
cd ..

title "已安装软件清单..."
custom_col1_width=22
custom_col2_width=32
source platform/Darwin/common.sh

fun_print_table_header "Installed State" "Component" "Version"
dependency_commands=(git rbenv ruby gem bundle)
for cmd in ${dependency_commands[@]}; do
    version=$(${cmd} --version)
    printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
done
fun_print_table_footer

title "sypctl 约束配置..."
sypctl ssh-keygen > /dev/null 2>&1

title "sypctl 基础服务配置..."
sypctl toolkit date check
sypctl schedule:update
sypctl schedule:jobs

title "sypctl 安装完成"
sypctl help