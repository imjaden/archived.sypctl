#!/usr/bin/env bash

test -f ~/.bash_profile && source ~/.bash_profile

command -v lsb_release > /dev/null || {
    command -v yum > /dev/null && yum install -y redhat-lsb
    command -v apt-get > /dev/null && apt-get install -y lsb-release
}

supported_os_platforms=(RedHatEnterpriseServer6 RedHatEnterpriseServer7 CentOS6 CentOS7 Ubuntu16)
os_platform="UnknownOS"
system=$(lsb_release -i | awk '{ print $3 }')
version=$(lsb_release -r | awk '{ print $2 }' | awk -F . '{print $1 }')
if [[ "${supported_os_platforms[@]}" =~ "${system}${version}" ]]; then
    os_platform="${system}${version}"
else
    echo "ERROR: unsupport system!"
    exit 1
fi

command -v yum > /dev/null && {
    # yum update -y

    packages=(git vim wget bzip2 gcc gcc-c++ automake autoconf libtool make openssl openssl-devel readline-devel zlib-devel readline-devel libxslt-devel.x86_64 libxml2-devel.x86_64 tree)
    for package in ${packages[@]}; do
      command -v ${package} > /dev/null || {
          printf "installing ${package}..."
          yum install -y ${package} > /dev/null 2>&1
          printf "$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')\n"
      }
    done
}
command -v apt-get > /dev/null && {
    # apt-get update -y

    packages=(git git-core git-doc lsb-release curl libreadline-dev libcurl4-gnutls-dev libssl-dev libexpat1-dev gettext libz-dev tree language-pack-zh-hant language-pack-zh-hans)
    for package in ${packages[@]}; do
      command -v ${package} > /dev/null || {
          printf "installing ${package}..."
          apt-get build-dep -y ${package} > /dev/null 2>&1
          apt-get install -y ${package} > /dev/null 2>&1
          printf "$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')\n"
      }
    done
}

test -d /opt/scripts/syp-saas-scripts || {
    mkdir -p /opt/scripts/
    cd /opt/scripts
    git clone --branch dev-0.0.1 --depth 1 http://gitlab.ibi.ren/syp/syp-saas-scripts.git
    cd syp-saas-scripts
}

cd /opt/scripts/syp-saas-scripts
git pull origin dev-0.0.1 > /dev/null 2>&1
bash server/bash/jdk-tools.sh install

command -v rbenv >/dev/null 2>&1 && { rbenv -v; type rbenv; } || { 
    git clone --depth 1 git://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone --depth 1  git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    git clone --depth 1  git://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
    git clone --depth 1  https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
    git clone --depth 1  https://github.com/andorchen/rbenv-china-mirror.git ~/.rbenv/plugins/rbenv-china-mirror
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
    source ~/.bash_profile
    type rbenv
}

command -v ruby >/dev/null 2>&1 && ruby -v || { 
    rbenv install 2.4.0
    rbenv rehash
    rbenv global 2.4.0
    ruby -v
}

command -v bundle >/dev/null 2>&1 && bundle -v || { 
    gem install bundle
    bundle config mirror.https://rubygems.org https://gems.ruby-china.org
    bundle config build.nokogiri --use-system-libraries
}

custom_col1_width=22
custom_col2_width=32
source server/bash/common.sh

fun_print_table_header "Installed State" "Component" "Version"
dependency_commands=(git rbenv ruby gem bundle)
for cmd in ${dependency_commands[@]}; do
    version=$(${cmd} --version)
    printf "$two_cols_table_format" "${cmd}" "${version:0:30}"
done
fun_prompt_java_already_installed
fun_print_table_footer

command -v sypctl >/dev/null 2>&1 && sypctl help || { 
    echo "alias sypctl=/opt/scripts/syp-saas-scripts/sypctl.sh" >> ~/.bash_profile
    bash /opt/scripts/syp-saas-scripts/sypctl.sh help  
}