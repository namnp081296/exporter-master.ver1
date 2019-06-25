#!/bin/bash

# Create folder to save all service backup file
# mkdir service_backup
CUR_DIR=`pwd`

# Copy all binary file from current folder to /usr/local/bin 
sudo cp $CUR_DIR/bin/* /usr/local/bin

# Create user with no create home and set owner to run exporter
sudo chown prometheus:prometheus /usr/local/bin/*_exporter

# Before we start running exporter. We should check existing port in server
newport=0
# Create Array list with key: name of service and value: port of service
declare -A arr_port
arr_port+=( ["php_fpm"]=8080 ["mongodb"]=9001 ["node"]=9100 ["mysqld"]=9104 ["redis"]=9121 ["nginx"]=9913 ["merger"]=39000 )

# Function Random port
function random_unused_port() {
   shuf -i 1-100 -n 1
}

function get_version_centos() {
#cat /etc/os-release | grep 'VERSION_ID=' | awk -F '=' '{print $2}' | awk -F "" '{print $2}'
    rpm -q --queryformat '%{VERSION}' centos-release
}

# FUNCTION FOR CENTOS 6
function centos_six() {
# Create a merger.yml file
cat << ADDTEXT | sudo tee -a /etc/merger.yaml
exporters:
ADDTEXT

for expter in "${!arr_port[@]}"
    do
    netstat -lat | grep ${arr_port[${expter}]}  > /dev/null
    if [[ $? == 1 ]] ; then
      default_port=${arr_port[${expter}]}
      #echo "Port is valid and the default port is ${arr_port[${expter}]}"
      
      # Create variable for 
      PROGNAME=${expter}_exporter
      PROG=/usr/local/bin/$PROGNAME
      USER=root
      LOGFILE=/var/log/$PROGNAME.log
      LOCKFILE=/var/run/$PROGNAME.pid

      cat << ADDPORT | sudo tee -a /etc/rc.d/init.d/${expter}_exporter
#!/bin/bash

# Source function library.
. /etc/rc.d/init.d/functions

PROGNAME=${PROGNAME}
PROG=${PROG}
USER=${USER}
LOGFILE=/var/log/${PROGNAME}.log
LOCKFILE=/var/run/${PROGNAME}.pid


start() {
    echo -n "Starting ${PROGNAME}: "
    daemon --user ${USER} --pidfile="${LOGFILE}" "${PROG} `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$default_port &>${LOGFILE} &"
    echo
}

stop() {
    echo -n "Shutting down ${PROGNAME}: "
    killproc ${PROGNAME}
    rm -f ${LOCKFILE}
    echo
}

case "\$1" in
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
        echo "Usage: service ${expter}_exporter {start|stop|status|reload|restart}"
        exit 1
    ;;
esac
ADDPORT

     cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$default_port/metrics
ADDTEXT
    else
        #echo "Port is in used"
        rd=$(random_unused_port)
        #echo "Random port is $rd"
        newport=$(( default_port + rd ))
        #echo "Your new port is: $newport "
        while true;
        do
           netstat -lat | grep $newport > /dev/null
           if [ $? == 1 ] ; then
             cat << ADDPORT | sudo tee -a /etc/rc.d/init.d/${expter}_exporter
#!/bin/bash

# Source function library.
. /etc/rc.d/init.d/functions

PROGNAME=${PROGNAME}
PROG=${PROG}
USER=${USER}
LOGFILE=/var/log/${PROGNAME}.log
LOCKFILE=/var/run/${PROGNAME}.pid


start() {
    echo -n "Starting ${PROGNAME}: "
    daemon --user ${USER} --pidfile="${LOGFILE}" "${PROG} `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$newport &>${LOGFILE} &"
    echo
}

stop() {
    echo -n "Shutting down ${PROGNAME}: "
    killproc ${PROGNAME}
    rm -f ${LOCKFILE}
    echo
}

case "\$1" in
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
        echo "Usage: service ${expter}_exporter {start|stop|status|reload|restart}"
        exit 1
    ;;
esac
ADDPORT
             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport/metrics
ADDTEXT

             echo "Port $newport is validable"
             break;
           else
             newport_rand=$(( newport + rd ))
             echo "Your new port is $newport_rand"
             cat << ADDPORT | sudo tee -a /etc/rc.d/init.d/${expter}_exporter
#!/bin/bash

# Source function library.
. /etc/rc.d/init.d/functions

PROGNAME=${PROGNAME}
PROG=${PROG}
USER=${USER}
LOGFILE=/var/log/${PROGNAME}.log
LOCKFILE=/var/run/${PROGNAME}.pid

start() {
    echo -n "Starting ${PROGNAME}: "
    daemon --user ${USER} --pidfile="${LOGFILE}" "${PROG} `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$newport_rand &>${LOGFILE} &"
    echo
}

stop() {
    echo -n "Shutting down ${PROGNAME}: "
    killproc ${PROGNAME}
    rm -f ${LOCKFILE}
    echo
}

case "\$1" in
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
        echo "Usage: service ${expter}_exporter {start|stop|status|reload|restart}"
        exit 1
    ;;
esac
ADDPORT

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport_rand/metrics
ADDTEXT
           fi
        done
    fi
 
 sudo chmod 755 /etc/init.d/*_exporter
 sudo service ${expter}_exporter start
 sudo service ${expter}_exporter status
done
}

# CENTOS 7
function centos_seven(){
# Create a merger.yml file
cat << ADDTEXT | sudo tee -a /etc/merger.yaml
exporters:
ADDTEXT

for expter in "${!arr_port[@]}"
  do
    netstat -lat | grep ${arr_port[${expter}]}  > /dev/null
    if [[ $? == 1 ]] ; then
      default_port=${arr_port[${expter}]}
      #echo "Port is valid and the default port is ${arr_port[${expter}]}"      
# Create exporter service file
      cat << ADDPORT | sudo tee -a /etc/systemd/system/${expter}_exporter.service
[Unit]
Description=${expter} exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/${expter}_exporter `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$default_port

[Install]
WantedBy=multi-user.target
ADDPORT

# Add exporter url to merger.yml file
      cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$default_port/metrics
ADDTEXT

    else
        #echo "Port is in used"
        rd=$(random_unused_port)
        #echo "Random port is $rd"
        newport=$(( default_port + rd ))
        #echo "Your new port is: $newport "
        while true; 
        do
           netstat -lat | grep $newport > /dev/null
           if [ $? == 1 ] ; then
             cat << ADDPORT | sudo tee -a /etc/systemd/system/${expter}_exporter.service
[Unit]
Description=${expter} exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/${expter}_exporter `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$newport

[Install]
WantedBy=multi-user.target
ADDPORT

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport/metrics
ADDTEXT

             #echo "Port $newport is validable"
             break;
           else
             newport_rand=$(( newport + rd ))
             #echo "Your new port is $newport_rand"
             cat << ADDPORT | sudo tee -a /etc/systemd/system/${expter}_exporter.service
[Unit]
Description=${expter} exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/${expter}_exporter `/bin/bash $CUR_DIR/yaml_handler/parse_yml.sh ${expter}`$newport_rand

[Install]
WantedBy=multi-user.target
ADDPORT

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport_rand/metrics
ADDTEXT

           fi
        done
    fi

# Reload daemon then start, enable and check status.
sudo systemctl daemon-reload
sudo systemctl start ${expter}_exporter.service
sudo systemctl enable ${expter}_exporter.service
sudo systemctl status ${expter}_exporter.service
done

}

function main() {
    ver=$(get_version_centos)
    if [[ $ver == 7 ]] ; then 
       centos_seven
    else
       centos_six
    fi
}
main
