#!/bin/bash
# web login & set syslog scripts
# creaty by zino.k

user="admin"
pass="admin"
syslog_ip=""
ip=$1


# login
COOKIE=`curl -s -L -H "Connection: keep-alive" -d "WEBVAR_USERNAME=${user}&WEBVAR_PASSWORD=${pass}" "http://${ip}/rpc/WEBSES/create.asp"|awk -F ':' '/SESSION_COOKIE/ {gsub(/\,.*| /,"");print $2}'`

# set syslog
RS=`curl --cookie SessionCookie="${COOKIE//\'/}" -s -L -H "Connection: keep-alive" -H "Content-Type: application/json;charset=UTF-8" -d "AUDITENABLE=1&SYSLOGENABLE=2&FILESIZE=50000&ROTATECNT=0&SERVERADDR=${syslog_ip}" "http://${ip}/rpc/setlogcfg.asp"|grep 'HAPI_STATUS:0'`
curl -b cookie.txt -s -o /dev/null -H "Connection: close" "http://${ip}/rpc/WEBSES/logout.asp"

if [ "$RS" != "" ];then
  echo "success"
else
  echo "failure"
fi
