
#!/usr/bin/env bash
#
########################################
#  
#  VNC Tool
#
########################################
#
source server/bash/common.sh

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
            yum check-update
            yum groupinstall -y "GNOME Desktop" 
            yum groupinstall -y "X Window System"
            yum groupinstall -y "Graphical Administration Tools"
            yum group list

            yum install -y gnome-classic-session gnome-terminal nautilus-open-terminal control-center liberation-mono-fonts
            unlink /etc/systemd/system/default.target
            ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target
        }
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