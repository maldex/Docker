#!/bin/bash

echo -e "$0\t\t\t]]]]]]]] learning user and group from httpd.conf [[[[[[[["
user=`sed -n -e 's/^User \(.*\)/\1/p' /etc/httpd/conf/httpd.conf`
group=`sed -n -e 's/^User \(.*\)/\1/p' /etc/httpd/conf/httpd.conf`

echo -en "user '${user}'\t\t"; getent passwd ${user}
echo -en "group '${group}'\t\t"; getent group ${group}
echo -e "hostname\t\t${HOSTNAME}"

#echo -e "$0\t\t\t]]]]]]]] adjusting ServerName [[[[[[[["
#sed -i 's/^.#ServerName .*/ServerName ${HOSTNAME}/g' /etc/httpd/conf/httpd.conf
#sed -i 's/{HOSTNAME}/'${HOSTNAME}'/g' /var/www/html/index.html

echo -e "$0\t\t\t]]]]]]]] list apache modules [[[[[[[["
httpd -M

echo -e "$0\t\t\t]]]]]]]] list apache configuration [[[[[[[["
httpd -S 

echo -e "$0\t\t\t]]]]]]]] starting apache [[[[[[[["
httpd -D FOREGROUND 
retval=$?
echo -e "$0\t\t\t]]]]]]]] exit with ${retval} [[[[[[[["

exit $?