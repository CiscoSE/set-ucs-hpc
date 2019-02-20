#!/bin/bash

# Copyright (c) 2019 Cisco and/or its affiliates.

# This software is licensed to you under the terms of the Cisco Sample
# Code License, Version 1.0 (the "License"). You may obtain a copy of the
# License at

#               https://developer.cisco.com/docs/licenses

# All use of the material herein must be in accordance with the terms of
# the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.

Server=10.82.6.49
userName='admin'

showHelp() {
  cat << EOF
  Usage: ${0##*/} [--server [IP]] [--user [User]]...

  Where:

      -h               Display this help and exit
      --server         IP or fqdn of UCS Server Integrated Management Controller to be changed
      --user           Username to access API
      -v               verbose mode.
EOF
}

#Color Coding for screen output.
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[1;0m"

function exitRoutine () {
  #Use this instead of the exit command to ensure we clean up the cookies.
  if [ -n "${authCookie}" ]; then
    killCookie=$(accessUCS 'POST' "https://${Server/nuova}" "<aaaLogout inCookie='$authCookie'/>") 
    printf "%5s[ ${green} INFO ${normal} ] Removing CIMC cookie\n"
  fi
  exit
}

function accessUCS () {
  XMLResult=''
  errorCode=''
  errorText=''
  XMLResult=$(curl -skX ${1} ${2} -d "${3}"  --header "content-type: appliation/xml, accept: application/xml" --insecure ) 
  errorCode=$(echo $XMLResult | grep -oE "errorCode=\".*"  | sed "s/errorCode=\"//" | sed "s/\".*//")
  errorText=$(echo $XMLResult | grep -oE "errorDescr=\".*"  | sed "s/errorDescr=\"//" | sed "s/\".*//")
  #used only for debuging
  if [ "${4}" = 'TRUE' ]; then
        printf "Type: ${1}\n" >&2
        printf "URL: ${2}\n" >&2
        printf "XML Sent:\n${3}\n" >&2
        printf "XML Result:\n${XMLResult}\n\n" >&2
        printf "Error Code: ${errorCode}\n\n" >&2
        printf "Error Text: ${errorText}\n\n" >&2
  fi
  if [ -n "${errorCode}" ]; then
    writeStatus "UCS Call Failed.\n\tError Code: ${errorCode}\n\tXML Result: ${XMLResult}\n\tType: ${1}\n\tURL: ${2}\n\tXML: \n\t${3}\n" 'FAIL'
  fi
  if [ "${writeLog}" = 'enabled' ]; then
        printf "Type: ${1}" >> $writeLogFile
        printf "URL: ${2}" >> $writeLogFile
        printf "XML Sent:\n${3}\n\n" >> $writeLogFile
        printf "XML Result:\n${XMLResult}\n\n" >> $writeLogFile
  fi
  #if [ "${4}" = 'TRUE' ]; then
  #  exitRoutine
  #fi
  echo $XMLResult
}

function getCookie () {
        #Remove a cookie if it exists
        printf "Enter the password for the Server CIMC:\t" >&2
        read -s password
        printf "\n" >&2
        cookieResult=$(accessUCS "POST" "https://${Server}/nuova" "<aaaLogin inName='${userName}' inPassword='${password}'></aaaLogin>")
        echo $cookieResult | grep -oE "outCookie=\".*" | sed "s/outCookie=\"//" | sed "s/\".*//"
        if [ "${writeLog}" = 'enabled' ]; then
          printf "Type: ${1}" >> $writeLogFile
          printf "URL: ${2}" >> $writeLogFile
          printf "XML Sent:\n${3}\n\n" >> $writeLogFile
          printf "XML Result:\n${XMLResult}\n\n" >> $writeLogFile
        fi
}

function writeStatus (){
  if [ "${2}" = "FAIL" ]; then
    printf "%5s[ ${red} FAIL ${normal} ] ${1}\n" >&2
    # Begin Exit Reroutine
    exitRoutine
  fi

  printf "%5s[ ${green} INFO ${normal} ] ${1}\n" >&2

  if [ "${writeLog}" = 'enabled' ]; then
    printf "%5s[ ${green} INFO ${normal} ] ${1}\n" >> $writeLogFile
  fi
}
#Failure exits script
set -e

authCookie=''
authCookie=$(getCookie)
if [ -z "${authCookie}" ]; then
  writeStatus "Could not obtain Cookie." "FAIL"
fi
writeStatus "Authoriziation Cookie Obtained"

writeStatus "Resetting Adaptor Settings to factory default"
adaptorReset="
<configConfMo cookie='${authCookie}' dn='sys/rack-unit-1/adaptor-MLOM' inHierarchical='false'>
  <inConfig>
    <adaptorUnit adminState='adaptor-reset-default' dn='sys/rack-unit-1/adaptor-MLOM' status='modified' />
  </inConfig>
</configConfMo>
"
writeStatus "Reseting VIC Adaptor"
result=$(accessUCS 'POST' "https://${Server}/nuova" "${adaptorReset}" 'TRUE')
writeStatus "Adaptor Reset Complete"
adaptorProfileXML="
  <configConfMo cookie='${authCookie}' dn='sys/rack-unit-1/adaptor-MLOM' inHierarchical='false'>
    <inConfig>
      <adaptorUnit id='MLOM'>
        <adaptorGenProfile rn='general' lldp='Disabled'></adaptorGenProfile>
      </adaptorUnit>
    </inConfig>
  </configConfMo>
"
writeStatus "Writting Adaptor Profile"
result=$(accessUCS 'POST' "https://${Server}/nuova" "${adaptorProfileXML}")
writeStatus "Adaptor Proifile Complete"
interface0XML="
  <configConfMo cookie='${authCookie}' dn='sys/rack-unit-1/adaptor-MLOM/host-eth-eth0' inHierarchical='true'>
    <inConfig>
      <!--Setting the MTU to 9000. Default is 1500. Enabling PXE Boot-->
      <adaptorHostEthIf name='eth0' mtu='9000' pxeBoot='Enabled' rn='host-eth-eth0'>
      <!--Setting no VLAN ID and configuring for trunk. In this configuration same as an access port-->
      <adaptorEthGenProfile rn='general' vlan='NONE' vlanMode='TRUNK'></adaptorEthGenProfile>
          <adaptorEthRecvQueueProfile rn='eth-rcv-q' count='4' ringSize='512'></adaptorEthRecvQueueProfile>
          <adaptorEthWorkQueueProfile rn='eth-work-q' count='1' ringSize='256'></adaptorEthWorkQueueProfile>
        </adaptorHostEthIf>
    </inConfig>
  </configConfMo>
"
writeStatus "Setting configuration on adaptor 0"
result=$(accessUCS 'POST' "https://${Server}/nuova" "${interface0XML}")
writeStatus "Adaptor 0 Configuration Complete"
interface1XML="
  <configConfMo cookie='${authCookie}' dn='sys/rack-unit-1/adaptor-MLOM/host-eth-eth1' inHierarchical='true'>
    <inConfig>
      <!--Setting the MTU to 9000. Default is 1500. Enabling PXE Boot-->
      <adaptorHostEthIf name='eth1' mtu='9000' pxeBoot='Enabled' rn='host-eth-eth1'>
      <!--Setting no VLAN ID and configuring for trunk. In this configuration same as an access port-->
      <adaptorEthGenProfile rn='general' vlan='NONE' vlanMode='TRUNK'></adaptorEthGenProfile>
          <adaptorEthRecvQueueProfile rn='eth-rcv-q' count='4' ringSize='512'></adaptorEthRecvQueueProfile>
          <adaptorEthWorkQueueProfile rn='eth-work-q' count='1' ringSize='256'></adaptorEthWorkQueueProfile>
        </adaptorHostEthIf>
    </inConfig>
  </configConfMo>
"
writeStatus "Setting configuration on adaptor 1"
result=$(accessUCS 'POST' "https://${Server}/nuova" "${interface1XML}")
writeStatus "Adaptor 1 Configuration Complete"
#Final Cleanup.
exitRoutine