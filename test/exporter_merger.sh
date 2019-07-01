#!/bin/bash

# Set HOMEPATH & BIN_PATH
HOME_PATH="/etc/prometheus/exporter-master"
BIN_PATH="/usr/local/bin"

# Function check user exist
function check_user_exist() {
    
    getent passwd prometheus > /dev/null 2&>1

    if [ $? -eq 0 ]; then
       echo "User exists"
    else
       echo "Can create user."
       sudo useradd --no-create-home --shell /bin/false prometheus
    fi
}

# Function get version Centos
function get_version_centos() {
#cat /etc/os-release | grep 'VERSION_ID=' | awk -F '=' '{print $2}' | awk -F "" '{print $2}'
    rpm -q --queryformat '%{VERSION}' centos-release
}

# FUNCTION FOR CENTOS 6
function centos_six() {

PROGNAME="exporter_merger"
PROG="${BIN_PATH}/${PROGNAME}"
USER="prometheus"
sudo touch /var/log/$USER/$PROGNAME.log
LOGFILE="/var/log/${USER}/${PROGNAME}.log"
sudo touch /var/run/$USER/$PROGNAME.pid
PIDFILE="/var/run/${USER}/${PROGNAME}.pid"
LOCKFILE="/var/lock/subsys/${PROGNAME}"
RETVAL=0

merger_port=11011      
      
         sudo bash -c "cat << 'EOF' > /etc/rc.d/init.d/exporter_merger
#!/bin/bash

# Source function library.
. /etc/rc.d/init.d/functions

PROGNAME=${PROGNAME}
PROG=${PROG}
USER=${USER}
LOGFILE=${LOGFILE}
PIDFILE=${PIDFILE}

start() {
    echo -n "\"" Starting ${PROGNAME} "\"":
    daemon --user ${USER} --pidfile="\""${PIDFILE}"\"" "\""${PROG} `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh merger`${merger_port} &>${LOGFILE} &"\""
    RETVAL=${RETVAL}
    echo
    [ ${RETVAL} -eq 0 ] && sudo touch ${LOCKFILE}
    echo
}

stop() {
    echo -n "\"" Shutting down ${PROGNAME}: "\""
    killproc ${PROGNAME}
    rm -f ${LOCKFILE}
    echo
}

case "\""\$1"\"" in
    start)
    start
    ;;
    stop)
    stop
    ;;
    status)
    status ${PROGNAME}
    ;;
    restart)
    stop
    start
    ;;
    *)
        echo  "\""Usage: service exporter_merger {start|stop|status|reload|restart} "\""
        exit 1
    ;;
esac
EOF"

SERVICE="exporter_merger"
sudo chown -R prometheus:prometheus /etc/rc.d/init.d/$SERVICE
sudo chmod 755 /etc/rc.d/init.d/$SERVICE

pidof -x $SERVICE > /dev/null
if [[ $? == 1 ]] ; then
      #echo "$SERVICE is not running"
      sudo service $SERVICE start
      sudo service $SERVICE status
else
      #echo "$SERVICE running"
      sudo service $SERVICE restart
      sudo service $SERVICE status
fi

}

# CENTOS 7
function centos_seven(){

merger_port=11011

       sudo bash -c "cat << 'EOF' > /etc/systemd/system/exporter_merger.service
[Unit]
Description= exporter merger
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=${BIN_PATH}/exporter_merger `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh merger`${merger_port}

[Install]
WantedBy=multi-user.target
EOF"

# Reload daemon then start, enable and check status.
SERVICE="exporter_merger.service"
sudo systemctl daemon-reload
pidof -x $SERVICE > /dev/null
 if [[ $? == 1 ]] ; then
      #echo "$SERVICE is not running"
      sudo systemctl start $SERVICE
      sudo systemctl enable $SERVICE
      sudo systemctl status $SERVICE
 else
      #echo "$SERVICE running"
      sudo systemctl restart $SERVICE
      sudo systemctl status $SERVICE
 fi
}

## MAIN FUNCTION ###
function main() {
    
    check_user_exist
    
    sudo mkdir -p /var/log/prometheus/
    sudo mkdir -p /var/run/prometheus/
    sudo chown -R prometheus:prometheus /var/log/prometheus
    sudo chown -R prometheus:prometheus /var/run/prometheus
    
    ver=$(get_version_centos)
    if [[ $ver == 7 ]] ; then 
       centos_seven
    else
       centos_six
    fi
}
main