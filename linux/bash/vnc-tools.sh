
#!/usr/bin/env bash
#
########################################
#  
#  VNC Tool
#
########################################
#
source linux/bash/common.sh

cmd_type="${1:-start}"
option="${2:-use-header}"
case "${cmd_type}" in 
    install|deploy)
        command -v vncserver >/dev/null 2>&1 || {
            yum install -y tigervnc-server vnc
        }
        test -f /etc/systemd/system/vncserver@:1.service || {
            cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:1.service
        }
        fun_prompt_vncserver_already_installed

        test -z "$DESKTOP_SESSION" && {
            yum upgrade -y
            yum groupinstall -y "GNOME 桌面" 
            yum groupinstall -y "GNOME Desktop" 
            yum groupinstall -y "X Window System"
            yum groupinstall -y "图形管理工具"
            yum groupinstall -y "Graphical Administration Tools"

            test -z "$DESKTOP_SESSION" && {
                echo "GNOME Desktop 安装失败，若提示：fwupdate-efi 与 grub2-common 冲突，请尝试下方命令:"
                echo
                echo "\$ yum update -y grub2-common"
                echo "\$ yum install fwupdate-efi"
                echo
                echo "查看系统支持的组件:"
                echo
                echo "\$ yum group list"
                echo

                exit 1
            }

            yum group list

            yum install -y gnome-classic-session gnome-terminal nautilus-open-terminal control-center liberation-mono-fonts
            ln -snf /lib/systemd/system/graphical.target /etc/systemd/system/default.target
        }

        yum install -y git cmake jq gnome-shell-browser-plugin gnome-tweak-tool gnome-shell* gstreamer-python
    ;;
    list|status)
        vncserver -list
    ;;
    start)
        vncserver -geometry 1024x768 -depth 24
    ;;
    stop)
        vncserver -list | grep -e ^: | awk '{ print $1 }' | xargs vncserver -kill
    ;;
    monitor)
        service_count=$(vncserver -list | grep -e ^: | wc -l)
        [[ ${service_count} -eq 0 ]] && bash $0 start
        bash $0 status
    ;;
    *)
        logger "warning: unkown params - $@"
        logger
        logger "Usage:"
        logger "    $0 install|deplo"
        logger "    $0 list|status"
        logger "    $0 start"
        logger "    $0 stop"
        logger "    $0 monitor"
    ;;
esac