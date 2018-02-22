#!/usr/bin/env bash

function fun_prompt_command_already_installed() {
    command_name=$1
    version_lines=${2:-2}

    test -z "${command_name}" && {
        echo "warning: fun_prompt_command_already_installed need pass command name as paramters!";return 2
    }

    echo >&2 "${command_name} already installed:"
    echo
    echo "$ which ${command_name}"
    which ${command_name}
    echo "$ ${command_name} -v"
    ${command_name} -v | grep -v ^$ | head -n ${version_lines}
}

case "$1" in
    check)
        echo "========================================"
        bash $0 check:zip
        echo "========================================"
        bash $0 check:unzip
        echo "========================================"
        bash $0 check:unrar
        echo "========================================"
    ;;
    check:zip)
        command -v zip >/dev/null 2>&1 && fun_prompt_command_already_installed zip || {
            echo "zip command not found then installing..."
            yum install -y zip > /dev/null 2>&1
            bash $0 check:zip
        }
    ;;
    check:unzip)
        command -v unzip >/dev/null 2>&1 && fun_prompt_command_already_installed unzip || {
            echo "unzip command not found then installing..."
            yum install -y unzip > /dev/null 2>&1
            bash $0 check:unzip
        }
    ;;
    check:rar|check:unrar)
        command -v rar >/dev/null 2>&1 && {
            fun_prompt_command_already_installed rar 
            fun_prompt_command_already_installed unrar 
        } || {
            echo "rar command not found then installing..."
            mkdir -p ~/tools && cd ~/tools
            test -f rarlinux-x64-4.2.0.tar.gz && rm -f rarlinux-x64-4.2.0.tar.gz
            test -d /usr/local/src/rar && rm -fr /usr/local/src/rar

            wget http://www.rarlab.com/rar/rarlinux-x64-4.2.0.tar.gz
            tar zxvf rarlinux-x64-4.2.0.tar.gz -C /usr/local/src 
            cd -

            ln -sf /usr/local/src/rar/rar /usr/local/bin/rar
            ln -sf /usr/local/src/rar/unrar /usr/local/bin/unrar
            bash $0 check:rar
        }
    ;;
    *)
        bash $0 check
    ;;
esac