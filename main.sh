#!/bin/bash

# Create prometheus folder in /etc/
sudo mkdir /etc/prometheus

# Move prometheus-exporter to /etc/prometheus/ path
sudo mv ~/exporter /etc/prometheus/exporter-master

# Set HOMEPATH
HOME_PATH=/etc/prometheus/exporter-master

# Create folder log and run for user:prometheus
# sudo mkdir -p /var/log/prometheus/
# sudo mkdir -p /var/run/prometheus/
# sudo chown -R prometheus:prometheus /var/log/prometheus
# sudo chown -R prometheus:prometheus /var/run/prometheus

# Before we start running exporter. We should check existing port in server
newport=0
# Create Array list with key: name of service and value
declare -a arr_port
arr_port=("php_fpm" "mongodb" "node" "mysqld" "redis" "nginx" "merger" "haproxy" "kafka" "memcached" "couchbase")

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

# Function check file exist then copy to /usr/local/bin
function check_file_exist() {
  for expter in "${arr_port[@]}"
  do
    FILE=/usr/local/bin/exporter_${expter}
    if [[ ! -e "$FILE" ]]
    then       
        #echo "file exporter_${expter} not exist"
        sudo cp $HOME_PATH/bin/exporter_${expter} /usr/local/bin/
        sudo chown -R prometheus:prometheus /usr/local/bin/exporter_${expter}
        sudo chmod +x /usr/local/bin/exporter_${expter}
    else
        echo "file exporter_${expter} exist"
    fi
  done   
  }

# Function Random port
function random_service_port() {
   shuf -i 11020-11050 -n 1
}

function random_unused_port() {
   shuf -i 1-100 -n 1
}

function get_version_centos() {
#cat /etc/os-release | grep 'VERSION_ID=' | awk -F '=' '{print $2}' | awk -F "" '{print $2}'
    rpm -q --queryformat '%{VERSION}' centos-release
}

# FUNCTION FOR CENTOS 6
function centos_six() {

ser=$(random_service_port)
# Create a merger.yml file
sudo bash -c "cat << 'EOF' > /etc/merger.yaml
exporters:
EOF"

for expter in "${arr_port[@]}"
    do
       PROGNAME=exporter_${expter}
       PROG=/usr/local/bin/$PROGNAME
       USER=prometheus
       LOGFILE=/var/log/$USER/$PROGNAME.log
       PIDFILE=/var/run/$USER/$PROGNAME.pid
       LOCKFILE=/var/lock/subsys/$PROGNAME
       RETVAL=0
       
       if [[ ${expter} == "merger" ]] ; then
         merger_port=11011

         sudo bash -c "cat << 'EOF' > /etc/rc.d/init.d/exporter_${expter}
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
    daemon --user ${USER} --pidfile="\""${PIDFILE}"\"" "\""${PROG} `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh ${expter}`$merger_port &>${LOGFILE} &"\""
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
        echo  "\""Usage: service exporter_${expter} {start|stop|status|reload|restart} "\""
        exit 1
    ;;
esac
EOF"

#        cat << ADDTEXT | sudo tee -a /etc/merger.yaml
# #${expter}
# - url: http://localhost:$merger_port/metrics
# ADDTEXT

       else
         sudo netstat -lntp | grep $ser  > /dev/null
         if [[ $? == 1 ]] ; then
         service_port=$ser
           
         sudo bash -c "cat << 'EOF' > /etc/rc.d/init.d/exporter_${expter}
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
    daemon --user ${USER} --pidfile="\""${PIDFILE}"\"" "\""${PROG} `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh ${expter}`$service_port &>${LOGFILE} &"\""
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
        echo  "\""Usage: service exporter_${expter} {start|stop|status|reload|restart} "\""
        exit 1
    ;;
esac
EOF"

     cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$service_port/metrics
ADDTEXT
    else
        #echo "Port is in used"
        rd=$(random_unused_port)
        #echo "Random port is $rd"
        newport=$(( service_port + rd ))
        #echo "Your new port is: $newport "
        while true;
        do
           sudo netstat -lntp | grep $newport > /dev/null
           if [ $? == 1 ] ; then
             sudo bash -c "cat << 'EOF' > /etc/rc.d/init.d/exporter_${expter}
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
    daemon --user ${USER} --pidfile="\""${PIDFILE}"\"" "\""${PROG} `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh ${expter}`$newport &>${LOGFILE} &"\""
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
        echo  "\""Usage: service exporter_${expter} {start|stop|status|reload|restart} "\""
        exit 1
    ;;
esac
EOF"
             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport/metrics
ADDTEXT
        
             break;
           else
             newport_rand=$(( newport + rd ))
             sudo bash -c "cat << 'EOF' > /etc/rc.d/init.d/exporter_${expter}
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
    daemon --user ${USER} --pidfile="\""${PIDFILE}"\"" "\""${PROG} `/bin/bash ${HOME_PATH}/yaml_handler/parse_yml.sh ${expter}`$newport_rand &>${LOGFILE} &"\""
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
        echo  "\""Usage: service exporter_${expter} {start|stop|status|reload|restart} "\""
        exit 1
    ;;
esac
EOF"

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport_rand/metrics
ADDTEXT
           fi
        done
    fi
 fi
 sudo chown -R prometheus:prometheus /etc/rc.d/init.d/exporter_*
 sudo chmod 755 /etc/rc.d/init.d/exporter_*
 sudo service exporter_${expter} start
 sudo service exporter_${expter} status

done
}

# CENTOS 7
function centos_seven(){

ser=$(random_service_port)

# Create a merger.yml file
sudo bash -c "cat << 'EOF' > /etc/merger.yaml
exporters:
EOF"

for expter in "${arr_port[@]}"
  do
    if [[ ${expter} == "merger" ]] ; then
       merger_port=11011
       sudo bash -c "cat << 'EOF' > /etc/systemd/system/exporter_${expter}.service
[Unit]
Description= exporter ${expter}
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/exporter_${expter} `/bin/bash $HOME_PATH/yaml_handler/parse_yml.sh ${expter}`$merger_port

[Install]
WantedBy=multi-user.target
EOF"

#        cat << ADDTEXT | sudo tee -a /etc/merger.yaml
# #${expter}
# - url: http://localhost:$merger_port/metrics
# ADDTEXT

    else
       sudo netstat -lntp | grep $ser  > /dev/null
       if [[ $? == 1 ]] ; then
          service_port=$ser
          # Create exporter service file
          sudo bash -c "cat << 'EOF' > /etc/systemd/system/exporter_${expter}.service
[Unit]
Description= exporter ${expter}
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/exporter_${expter} `/bin/bash $HOME_PATH/yaml_handler/parse_yml.sh ${expter}`$service_port

[Install]
WantedBy=multi-user.target
EOF"

# Add exporter url to merger.yml file
      cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$service_port/metrics
ADDTEXT

       else
        #echo "Port is in used"
        rd=$(random_unused_port)
        #echo "Random port is $rd"
        newport=$(( service_port + rd ))
        #echo "Your new port is: $newport "
        while true;
        do
           sudo netstat -lntp | grep $newport > /dev/null
           if [ $? == 1 ] ; then
             sudo bash -c "cat << 'EOF' >  /etc/systemd/system/exporter_${expter}.service
[Unit]
Description= exporter ${expter}
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/exporter_${expter} `/bin/bash $HOME_PATH/yaml_handler/parse_yml.sh ${expter}`$newport

[Install]
WantedBy=multi-user.target
EOF"

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport/metrics
ADDTEXT

             #echo "Port $newport is validable"
             break;
           else
             newport_rand=$(( newport + rd ))
             #echo "Your new port is $newport_rand"
             sudo bash -c "cat << 'EOF' >  /etc/systemd/system/exporter_${expter}.service
[Unit]
Description= exporter ${expter}
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/exporter_${expter} `/bin/bash $HOME_PATH/yaml_handler/parse_yml.sh ${expter}`$newport_rand

[Install]
WantedBy=multi-user.target
EOF"

             cat << ADDTEXT | sudo tee -a /etc/merger.yaml
#${expter}
- url: http://localhost:$newport_rand/metrics
ADDTEXT
           fi
        done
      fi
   fi
# Reload daemon then start, enable and check status.
sudo systemctl daemon-reload
sudo systemctl start exporter_${expter}.service
sudo systemctl enable exporter_${expter}.service
sudo systemctl status exporter_${expter}.service
done

}

## MAIN FUNCTION ###
function main() {
    
    check_user_exist
    
    sudo mkdir -p /var/log/prometheus/
    sudo mkdir -p /var/run/prometheus/
    sudo chown -R prometheus:prometheus /var/log/prometheus
    sudo chown -R prometheus:prometheus /var/run/prometheus

    check_file_exist
    
    ver=$(get_version_centos)
    if [[ $ver == 7 ]] ; then 
       centos_seven
    else
       centos_six
    fi
}
main