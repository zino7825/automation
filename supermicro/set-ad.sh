#!/bin/bash
#######################################
#
# AD/ldap configuration tool 
# create by zino
# 
# ./tool {bmc_IP}

USER="ADMIN"
PASS="ADMIN"
IPMI_HOST=$1
AD_IP=""
AD_DOMAIN="example.com"
LEGACY_CHECK=`ipmitool -I lanplus -U ADMIN -P ADMIN -H 172.26.16.57 fru print 0 |awk -F':' '/Board Product/ {print $NF}'`

if [[ $LEGACY =~ X9 ]];then
  curl -c cookie.txt -o /dev/null -H "Connection: Keep-Alive" -s -d "name=${USER}&pwd=${PASS}" "http://${IPMI_HOST}/cgi/login.cgi"
  curl -sL -d "enable_ad=1&enable_ssl=0&port=389&user_domain=${AD_DOMAIN}&server_ip1=${AD_IP}" "http://${IPMI_HOST}/cgi/config_ad.cgi" -b cookie.txt
  curl -skL -d "op=config_ad_server&enable_ad=1&enable_ssl=0&port=389&user_domain=${AD_DOMAIN}&server_ip1=${AD_IP}" "https://${IPMI_HOST}/cgi/op.cgi" -b cookie.txt
  ## sys-admin privilege
  curl -sL -d "groupname=SE_TEAM&groupidx=0&groupdomain=${AD_DOMAIN}&new_privilege=4" "http://${IPMI_HOST}/cgi/config_ad_group.cgi" -b cookie.txt
  ## operator privilege
  curl -sL -d "groupname=IDC_TEAM&groupidx=1&groupdomain=${AD_DOMAIN}&new_privilege=3" "http://${IPMI_HOST}/cgi/config_ad_group.cgi" -b cookie.txt
  curl -s -o /dev/null "http://${IPMI_HOST}/cgi/logout.cgi" -b cookie.txt
else
  curl -c cookie.txt -o /dev/null -skL -d "name=${USER}&pwd=${PASS}" "https://${IPMI_HOST}/cgi/login.cgi"
  curl -skL -d "op=config_ad_server&enable_ad=1&enable_ssl=0&port=389&user_domain=${AD_DOMAIN}&server_ip1=${AD_IP}" "https://${IPMI_HOST}/cgi/op.cgi" -b cookie.txt
  ## sys-admin privilege
  curl -s -skL -d "op=config_ad_group&groupname=SE_TEAM&groupidx=0&groupdomain=${AD_DOMAIN}&new_privilege=4" "https://${IPMI_HOST}/cgi/op.cgi" -b cookie.txt
  ## operator privilege
  curl -s -skL -d "op=config_ad_group&groupname=IDC_TEAM&groupidx=1&groupdomain=${AD_DOMAIN}&new_privilege=3" "https://${IPMI_HOST}/cgi/op.cgi" -b cookie.txt
  curl -s -o /dev/null "https://${IPMI_HOST}/cgi/logout.cgi" -b cookie.txt
fi


