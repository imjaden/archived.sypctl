#!/bin/bash

case "$1" in
    install)
        echo
        echo '## deploy jdk'
        echo
        bash lib/bash/jdk-tools.sh install

        echo
        echo '## deploy tomcat'
        echo
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAPI install 8080
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin install 8081

        echo
        echo '## deploy zookeeper'
        echo
        bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper install
    ;;
    start|stop|status|restart|monitor)
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAPI $1
        bash lib/bash/tomcat-tools.sh /usr/local/src/tomcatAdmin $1
        bash lib/bash/zookeeper-tools.sh /usr/local/src/zookeeper $1
    ;;
    *)
        logger "warning: unkown params - $@"
    ;;
esac