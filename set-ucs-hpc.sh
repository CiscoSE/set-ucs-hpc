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
result=$(accessUCS 'POST' "https://${Server}/nuova" "${adaptorReset}")
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
          <!--These are defualt settings, but provided for specific customer that wishes to tune these settings later.-->
          <adaptorEthRecvQueueProfile rn='eth-rcv-q' count='4' ringSize='512'></adaptorEthRecvQueueProfile>
          <adaptorEthWorkQueueProfile rn='eth-work-q' count='1' ringSize='256'></adaptorEthWorkQueueProfile>
        </adaptorHostEthIf>
    </inConfig>
  </configConfMo>
"
writeStatus "Setting configuration on adaptor 1"
result=$(accessUCS 'POST' "https://${Server}/nuova" "${interface1XML}")
writeStatus "Adaptor 1 Configuration Complete"

biosSettingsXML="
  <configConfMo cookie='${authCookie}' dn='sys/rack-unit-1/bios/bios-settings' inHierarchical='true'>
    <inConfig>
      <biosSettings rn='bios-settings'>
      <!-- HPC Recommendation is to disable Virtual Technology for Direct IO. -->
      <biosVfIntelVTForDirectedIO rn='Intel-VT-for-directed-IO' vpIntelVTDATSSupport='disabled' vpIntelVTDCoherencySupport='disabled' vpIntelVTForDirectedIO='disabled'></biosVfIntelVTForDirectedIO>
      <!-- HPC Recommendation is for Memory RAS Configuration to be set to Maxium Performance -->
      <biosVfSelectMemoryRASConfiguration rn='SelectMemory-RAS-configuration' vpSelectMemoryRASConfiguration='maximum-performance'></biosVfSelectMemoryRASConfiguration>
      <!-- HPC Recommendation is to disable C6 report. OS will not recieve report preventing the OS from placing the processors in a lower power state.-->
      <!--   This will result in increased power consumption for idle servers. -->
      <biosVfProcessorC6Report rn='Processor-C6-Report' vpProcessorC6Report='disabled'></biosVfProcessorC6Report>
      <!-- HPC recommendation is to disabling hyperthreading for HPC systems. -->
      <!--   CAUTION: We are not compliant with HPC recommendations with this setting in this script.-->
      <biosVfIntelHyperThreadingTech rn='Intel-HyperThreading-Tech' vpIntelHyperThreadingTech='enabled'></biosVfIntelHyperThreadingTech>
      <!-- HPC recommendation is to enable Intel Speed Step Technology. -->
      <biosVfEnhancedIntelSpeedStepTech rn='Enhanced-Intel-SpeedStep-Tech' vpEnhancedIntelSpeedStepTech='enabled'></biosVfEnhancedIntelSpeedStepTech>
      <!-- HPC recommendation is to disable Intel Virtualization Technology. -->
      <biosVfIntelVirtualizationTechnology rn='Intel-Virtualization-Technology' vpIntelVirtualizationTechnology='disabled'></biosVfIntelVirtualizationTechnology>
      <!-- Default setting for Mapped IO above 4K is retianed. No HPC recommendation documented. --> 
      <!-- Default setting retained for Adjacent Cache Line Prefetch. -->
      <biosVfMemoryMappedIOAbove4GB rn='Memory-mapped-IO-above-4GB' vpMemoryMappedIOAbove4GB='enabled'></biosVfMemoryMappedIOAbove4GB>
      <!-- HPC recommendation is for CPU Performance to be set to enterprise -->
      <biosVfCPUPerformance rn='CPU-Performance' vpCPUPerformance='enterprise'></biosVfCPUPerformance>
      <!-- HPC recommendation is for NUMA Optimization to be enabled -->
      <biosVfNUMAOptimized rn='NUMA-optimized' vpNUMAOptimized='enabled'></biosVfNUMAOptimized>
      <!-- Default setting for Conole Redirection is retained. No performance impact for these settings. Disabled for security purposes. -->
      <biosVfConsoleRedirection rn='Console-redirection' vpBaudRate='115200' vpConsoleRedirection='disabled' vpFlowControl='none' vpTerminalType='vt100'></biosVfConsoleRedirection>
      <!-- HPC recommendation is for Turbo Boost to be enabled. -->
      <biosVfIntelTurboBoostTech rn='Intel-Turbo-Boost-Tech' vpIntelTurboBoostTech='enabled'></biosVfIntelTurboBoostTech>
      <!-- Default setting for Exexute-Bit-Disabled retained. Enabled for security reasons. -->
      <biosVfExecuteDisableBit rn='Execute-Disable-Bit' vpExecuteDisableBit='enabled'></biosVfExecuteDisableBit>
      <!-- Default settings retained for OS Boot Watchdog Timers. No impact to HPC for these settings. -->
      <biosVfOSBootWatchdogTimer rn='OS-Boot-Watchdog-Timer-Param' vpOSBootWatchdogTimer='disabled'></biosVfOSBootWatchdogTimer>
      <biosVfOSBootWatchdogTimerPolicy rn='OS-Boot-Watchdog-Timer-Policy' vpOSBootWatchdogTimerPolicy='power-off'></biosVfOSBootWatchdogTimerPolicy>
      <biosVfOSBootWatchdogTimerTimeout rn='OS-Boot-Watchdog-Timer-Time-Out' vpOSBootWatchdogTimerTimeout='10-minutes'></biosVfOSBootWatchdogTimerTimeout>
      <!-- Default setting retained for Hardware Prefetch. Cisco recommends this remain on for all configurations. -->
      <biosVfHardwarePrefetch rn='Hardware-Prefetch' vpHardwarePrefetch='enabled'></biosVfHardwarePrefetch>
      <!-- Default setting retained for Adjacent Cache Line Prefetch. -->
      <!--    Note: No recommendation provided for performance  -->
      <biosVfAdjacentCacheLinePrefetch rn='Adjacent-Cache-Line-Prefetch' vpAdjacentCacheLinePrefetch='enabled'></biosVfAdjacentCacheLinePrefetch>
      <!-- Default setting retained for Fault Resilent Booting. Peformance is not impacted by this setting. -->
      <biosVfFRB2Enable rn='FRB2-Enable' vpFRB2Enable='enabled'></biosVfFRB2Enable>
      <!-- HPC recommendation is for Processor C1E to be disabled. -->
      <biosVfProcessorC1E rn='Processor-C1E' vpProcessorC1E='disabled'></biosVfProcessorC1E>
      <!-- Default setting retained for TPM Control. Performance is not impacted by this setting --> 
      <biosVfTPMControl rn='TPM-Control' vpTPMControl='disabled'></biosVfTPMControl>
      <!-- Default setting retained for TPM TXT Support. Performance is not impacted by this setting --> 
      <biosVfTXTSupport rn='TXT-Support' vpTXTSupport='disabled'></biosVfTXTSupport>
      <!-- Default setting retained for DCU Prefetcher -->
      <biosVfDCUPrefetch rn='DCU-Prefetch' vpStreamerPrefetch='enabled' vpIPPrefetch='enabled'></biosVfDCUPrefetch>
      <!-- Default setting retained for Legacy USB Support -->
      <biosVfLegacyUSBSupport rn='LegacyUSB-Support' vpLegacyUSBSupport='disabled'></biosVfLegacyUSBSupport>
      <!-- LOM Option ROM Disabled. This script uses the MLOM for PXE -->
      <biosVfLOMPortOptionROM rn='LOMPort-OptionROM' vpLOMPortsAllState='Disabled' vpLOMPort0State='Disabled' vpLOMPort1State='Disabled'></biosVfLOMPortOptionROM>
      <!-- PCI slots Disabled. MLOM, M.2 and HBA enabled --> 
      <biosVfPCISlotOptionROMEnable rn='PCI-Slot-OptionROM-Enable' vpSlot1State='Disabled' vpSlot2State='Disabled' vpSlot3State='Disabled' vpSlot4State='Disabled' vpSlot5State='Disabled' vpSlot6State='Disabled' vpSlotMLOMState='Enabled' vpSlotMRAIDState='Enabled' vpSlotMRAIDLinkSpeed='Auto' vpSlotN1State='Enabled' vpSlotN2State='Enabled' vpSlot1LinkSpeed='Auto' vpSlot2LinkSpeed='Auto' vpSlot3LinkSpeed='Auto' vpSlot4LinkSpeed='Auto' vpSlot5LinkSpeed='Auto' vpSlot6LinkSpeed='Auto' vpSlotMLOMLinkSpeed='Auto' vpSlotFrontNvme1LinkSpeed='Auto' vpSlotFrontNvme2LinkSpeed='Auto' vpSlotRearNvme1LinkSpeed='Auto' vpSlotRearNvme2LinkSpeed='Auto' vpSlotRearNvme1State='Enabled' vpSlotRearNvme2State='Enabled'></biosVfPCISlotOptionROMEnable>
      <!-- Default setting retained for Extended Advanced Programmable Interrupt Controller -->
      <biosVfExtendedAPIC rn='Extended-APIC' vpExtendedAPIC='Disabled'></biosVfExtendedAPIC>
      <!-- Default setting retained for Consistent Device Naming -->
      <biosVfCDNEnable rn='CDN-Enable' vpCDNEnable='Enabled'></biosVfCDNEnable>
      <!-- Default setting retained for Power On Password support -->
      <biosVfPowerOnPasswordSupport rn='POP-Support' vpPOPSupport='Disabled'></biosVfPowerOnPasswordSupport>
      <!-- Default setting retained for VGA Priority -->
      <biosVfVgaPriority rn='VgaPriority' vpVgaPriority='Onboard'></biosVfVgaPriority>
      <!-- Default setting retained for Boot Performance Mode --> 
      <biosVfBootPerformanceMode rn='Boot-Performance-Mode' vpBootPerformanceMode='Max Performance'></biosVfBootPerformanceMode>
      <!-- HPC recommendation is for Energy Performance to be set to Performance-->
      <biosVfCPUEnergyPerformance rn='CPU-EngPerfBias' vpCPUEnergyPerformance='performance'></biosVfCPUEnergyPerformance>
      <!-- Default setting retained for Corrected Machine Check Interrupt Enabled -->
      <biosVfCmciEnable rn='Cmci-Enable' vpCmciEnable='Enabled'></biosVfCmciEnable>
      <!-- Default setting retained for Hardware Power Management -->
      <biosVfHWPMEnable rn='HWPM-Enable' vpHWPMEnable='HWPM Native Mode'></biosVfHWPMEnable>
      <!-- HPC Recommendation is for Power State Coordinator to be set to HW ALL-->
      <biosVfPStateCoordType rn='p-state-coord' vpPStateCoordType='HW ALL'></biosVfPStateCoordType>
      <!-- HPC recommmendation is for Package CState Limit to be set to No Limit -->
      <biosVfPackageCStateLimit rn='Package-CState-Limit' vpPackageCStateLimit='No Limit'></biosVfPackageCStateLimit>
      <!-- Default setting retained for Memory Patrol Scrub --> 
      <biosVfPatrolScrub rn='Patrol-Scrub-Param' vpPatrolScrub='Enabled'></biosVfPatrolScrub>
      <!-- HPC recommendation is for Power Performance Tuning to be set to os -->
      <biosVfPwrPerfTuning rn='Pwr-Perf-Tuning' vpPwrPerfTuning='os'></biosVfPwrPerfTuning>
      <!-- HPC recommendation for Workload Config is Balanced -->
      <biosVfWorkLoadConfig rn='work-load-config' vpWorkLoadConfig='Balanced'></biosVfWorkLoadConfig>
      <!-- Default setting retained for Pch-Sata controller mode -->
      <biosVfSataModeSelect rn='Pch-Sata-Mode' vpSataModeSelect='AHCI'></biosVfSataModeSelect>
      <biosVfPSata rn='PSata' vpPSata='AHCI'></biosVfPSata>
      <!-- Default setting retained for Multi Core Processing - All cores active -->
      <biosVfCoreMultiProcessing rn='Core-MultiProcessing' vpCoreMultiProcessing='all'></biosVfCoreMultiProcessing>
      <!-- Default settings retained for Activation of USB ports. -->
      <biosVfUSBPortsConfig rn='USB-Ports-Config' vpUsbPortRear='enabled' vpUsbPortFront='enabled' vpUsbPortInternal='enabled' vpUsbPortKVM='enabled' vpUsbPortSDCard='disabled'></biosVfUSBPortsConfig>
      <!-- HPC recommendation is for IMC Ingerleave to remain at Auto -->
      <biosVfIMCInterleave rn='imc-interleave' vpIMCInterleave='Auto'></biosVfIMCInterleave>
      <!-- HPC recommendation is for sub numa clustering to be disabled -->
      <biosVfSubNumaClustering rn='sub-numa-cluster' vpSNC='Disabled'></biosVfSubNumaClustering>
      <!-- Default setting retained for KTI Prefech -->
      <biosVfKTIPrefetch rn='kti-prefetch' vpKTIPrefetch='Enabled'></biosVfKTIPrefetch>
      <!-- HPC recommencation is for XPT Prefetch to be disabled -->
      <biosVfXPTPrefetch rn='xpt-prefetch' vpXPTPrefetch='Disabled'></biosVfXPTPrefetch>
      <!-- HPC recommencation is for LLC Prefetch to be disabled -->
      <biosVfLLCPrefetch rn='LLC-Prefetch' vpLLCPrefetch='Disabled'></biosVfLLCPrefetch>
      <!-- Default setting retained for IPv6 PXE boot to be disabled -->
      <biosVfIPV6PXE rn='IPv6-Pxe' vpIPV6PXE='Disabled'></biosVfIPV6PXE>
      <!-- Default setting retained for Energy Efficient Turbo -->
      <biosVfEnergyEfficientTurbo rn='energy-efficient-turbo' vpEnergyEfficientTurbo='Disabled'></biosVfEnergyEfficientTurbo>
      <!-- Default setting retained for Auto CC State -->
      <biosVfAutoCCState rn='auto-cc-state' vpAutoCCState='Disabled'></biosVfAutoCCState>
      <!-- HPC recommendation is for Energy Performance Profile  is Performance -->
      <biosVfEPPProfile rn='epp-profile' vpEPPProfile='Performance'></biosVfEPPProfile>
      <!-- Default setting retained for bme-dma-mitigation retained -->
      <biosVfBmeDmaMitigation rn='bme-dma-mitigation' vpBmeDmaMitigation='Disabled'></biosVfBmeDmaMitigation>
      </biosSettings>
    </inConfig>
  </configConfMo>
"
writeStatus "Starting BIOS Settings"
result=$(accessUCS "POST" "https://${Server}/nuova" "${biosSettingsXML}")
writeStatus "BIOS Settings Complete"

#Final Cleanup.
exitRoutine