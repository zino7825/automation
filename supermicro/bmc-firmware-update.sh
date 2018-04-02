#!/bin/bash
#################################
#
# Supermicro Server : bmc firmware update tool
# 
# create by zino
#


USER="ADMIN"
PASS="ADMIN"
IPMI_HOST=$1
IMAGE_PATH=""
IMAGE_NAME=""
TARGET_VER="0399"

curl -c cookie.txt -o /dev/null -H "Connection: Keep-Alive" -s -d "name=${USER}&pwd=${PASS}" "http://${IPMI_HOST}/cgi/login.cgi"
VERSION=`curl -b cookie.txt -s -d "GENERIC_INFO.XML=(0,0)" "http://${IPMI_HOST}/cgi/ipmi.cgi"|grep -o 'IPMIFW_VERSION="[0-9]\+"'`
if [[ $VERSION =~ 0339 ]];then
 echo "$IPMI_MAC : alreay 0339"
 exit 1; 
fi
curl -b cookie.txt -v -L -H "Connection: Keep-Alive" -H "Upgrade-Insecure-Requests: 1" -H "Expect:" -F "form1=@${IMAGE_PATH};filename=${IMAGE_NAME}" "http://${IPMI_HOST}/cgi/oem_firmware_upload.cgi" 
curl -b cookie.txt -s -H "Connection: Keep-Alive" -v -d "preserve_config=1" "http://${IPMI_HOST}/cgi/oem_firmware_update.cgi"
curl -s -o /dev/null -H "Connection: close" "http://${IPMI_HOST}/cgi/logout.cgi" -b cookie.txt
