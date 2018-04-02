#!/bin/bash
# create by zino.k
#
# set raid on kickstart pre script
#
RC=`lspci|egrep 'RAID|SCSI'|cut -d':' -f3| cut -d' ' -f2`
OS_MAJOR_VER=`sed -r 's/.*release ([0-9]).*/\1/' /etc/redhat-release`
URL=""
LEVEL=$1
STRPSZ=${2:-128}
SKYLAKE=`lspci|grep -c "Sky Lake|Sky-Lake"`

exit_msg() {

  local msg=$1
  echo $msg; 
  exit 1;
}

if [ "$RC" == "Hewlett-Packard" -o "$RC" == "Compaq" ] ||  [ "$RC" == "Adaptec" -a $SKYLAKE -gt 0 ]; then
  [ ! -d /opt ] && mkdir /opt
  cd /opt
  if [ $SKYLAKE -gt 0 ];then
    wget http://$URL/ssacli.tgz
    tar xfz ssacli.tgz
    cmd="/opt/smartstorageadmin/ssacli/bin/ssacli"
    ssdover=" ssdoverprovisioningoptimization=off"
  else
    wget http://$URL/hp.tgz
    tar xfz hp.tgz
    cmd="/opt/hp/hpssacli/bld/hpssacli"
  fi
  $cmd ctrl all show config > /tmp/hpconfig
  slot_num=`sed -n 's/.*Slot \([0-9]\+\).*/\1/p' /tmp/hpconfig |head -1`
  pd_count=`grep -c physicaldrive /tmp/hpconfig`
  ld_array=(`sed -n 's/.*logicaldrive \([0-9]\+\).*/\1/p' /tmp/hpconfig`)

  if [ $pd_count -lt 2 ];then
    exit_msg "Not enough disk for raid setting"
  fi
  
  smart_array_clean() { 
    for ldnum in ${ld_array[@]}
    do
      $cmd ctrl slot=${slot_num} ld $ldnum delete forced
    done
    $cmd ctrl all show config > /tmp/hpconfig
  }
  case $LEVEL in
    1) 
      ## if there are 2 disk, raid1
      if [ $pd_count -eq 2 ];then
        smart_array_clean
        $cmd ctrl slot=${slot_num} create type=ld drives=allunassigned raid=1 stripsize=${STRPSZ}${ssdover} forced
      ## if there are greater than equl to 4 disk, raid1+0
      elif [  $pd_count -ge 4  -a $(( ${pd_count}%2 )) -eq 0  ];then
        smart_array_clean
        $cmd ctrl slot=${slot_num} create type=ld drives=allunassigned raid=1+0 stripsize=${STRPSZ}${ssdover} forced
      else
        exit_msg "can't set raid mirroring"
      fi
    ;;
    5)
      ## if there are greater than equl to 3 disk, raid5
      if [  $pd_count -ge 3 ];then
        smart_array_clean
        $cmd ctrl slot=${slot_num} create type=ld drives=allunassigned raid=5 stripsize=${STRPSZ}${ssdover} forced
      else
        exit_msg "can't set raid5"
      fi
    ;;
    jbod)
      ## if there are greater than or equl to 6 disk, raid1 + jbod
      if [  $pd_count -ge 6 ];then
        smart_array_clean
        os_pd=(`awk '/physical/ {print $2}' /tmp/hpconfig`)
        $cmd ctrl slot=${slot_num} create type=ld drives=${os_pd[0]},${os_pd[1]} raid=1 stripsize=${STRPSZ}${ssdover} forced
        for (( i=2; i< ${#os_pd[@]}; i=i+1 ))
        do
          $cmd ctrl slot=${slot_num} create type=ld drives=${os_pd[i]} raid=0 stripsize=${STRPSZ}${ssdover} forced
        done
      else
        exit_msg "can't set jbod cause not enough disk ($pd_count)"
      fi
    ;;
  esac
  
elif [ "$RC" == "LSI" -o "$RC" == "Dell" ];then
  if [ "`uname -i`" == "x86_64" ]; then
     CLI="MegaCli64"
  else
     CLI="MegaCli"
  fi
  [ ! -d /opt ] && mkdir /opt
  cd /opt
  wget http://$URL/${CLI}.tgz
  tar xfz ${CLI}.tgz
  chmod +x ${CLI}
  pd_list=(`./${CLI} -pdlist -aall|awk  '/^Enclosure Device/ { printf $NF} /^Slot/ { print ":"$NF}'`)
  all_disk=${pd_list[@]}
  lsi_clean() {
    ./${CLI} -CfgClr -aAll || ./${CLI} -CfgLdDel -Lall-force -aALL
    sleep 2
    ./${CLI} -PDMakeGood -PhysDrv[ ${all_disk// /,} ] -Force -a0
  }
  if [ ${#pd_list[@]} -lt 2 ];then
    exit_msg "Not enough disk for raid setting"
  fi
  case $LEVEL in
    1)
      ## if there are 2 disk, raid1
      if [ ${#pd_list[@]} -eq 2 ];then
        lsi_clean
        ./${CLI} -CfgLdAdd -r1[${pd_list[0]},${pd_list[1]}] WB Direct CachedBadBBU -strpsz${STRPSZ} -a0 
        ./${CLI} -AdpCacheFlush -aALL
      elif [ ${#pd_list[@]} -ge 4  -a $(( ${#pd_list[@]}%2 )) -eq 0  ];then
        lsi_clean
        ## if there are greater than equl to 4 disk, raid1+0
        for (( i=0; i< ${#pd_list[@]}; i=i+2 ))
        do
          array_cnt=$(($i/2))
          raid10="${raid10} -array${array_cnt}[${pd_list[$i]},${pd_list[$(($i+1))]}]"
        done
        ./${CLI} -CfgSpanAdd -r10 ${raid10} WB Direct CachedBadBBU -strpsz${STRPSZ} -a0
        ./${CLI} -AdpCacheFlush -aALL
      else
        exit_msg "can't set raid mirroring"
      fi
     ;;
    5)
      ## if there are greater than equl to 3 disk, raid5
      if [ ${#pd_list[@]} -ge 3 ];then

        lsi_clean
        ./${CLI} -CfgLdAdd -r5[${all_disk// /,}] WB Direct CachedBadBBU -strpsz${STRPSZ} -a0
        ./${CLI} -AdpCacheFlush -aALL
      else
        exit_msg "can't set raid5"
      fi
    ;;
    jbod)
      ## if there are greater than or equl to 6 disk, raid1 + jbod
      if [ ${#pd_list[@]} -ge 6 ];then
        lsi_clean
        ./${CLI} -CfgLdAdd -r1[${pd_list[0]},${pd_list[1]}] WB Direct CachedBadBBU -strpsz${STRPSZ} -a0
        for (( i=2; i< ${#pd_list[@]}; i=i+1 ))
        do
          ./${CLI} -CfgLdAdd -r0[${pd_list[i]}] WB Direct CachedBadBBU -strpsz${STRPSZ} -a0
        done
       ./${CLI} -AdpCacheFlush -aALL
      else
        exit_msg "can't set jbod cause not enough disk (${#pd_list[@]})"
      fi
    ;;
  esac
else 
  echo "Does not support $RC";
  exit 1;
fi
