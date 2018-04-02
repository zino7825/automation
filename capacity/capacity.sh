#!/bin/sh
#DATE=`date +%Y%m%d`
CPU_PA=0;
LOAD_PA=0;
SWAP_PA=0;
RX_PA=0;
TX_PA=0;

MINING_SYSTEM_TYPE (){

        # VMware = VM_VMware
        # XEN    = VM_XEN
        # Physical Machine = PM
        if [ -f "/sys/hypervisor/type" ];then
        SYSTEM_TYPE="VM_XEN"

        elif [[ `dmidecode | grep -w "Product Name"` =~ VMware ]];then
        SYSTEM_TYPE="VM_VMware"

        else
        SYSTEM_TYPE="PM"

        fi

}


export LC_ALL=C
SAR_FILES=`ls -t /var/log/sa/sa??|head -n 8|sed '1d'`
SAR_VER=`sar -V 2>&1|grep -o 'version [0-9]\+'|sed 's/version //'`

CPU ()
{

        SUM=0
        CN=0
        for i in $SAR_FILES
        do
                AVG=`sar -i 60 -f $i |sed '/CPU\|Average\|Linux\|^$/d'|awk '{print $NF}'|sort -n|head -10|awk '{idle=(100.0-$1) ; sum=sum+idle } END {printf "%0.2f \n", sum/NR}'`
                SUM=`echo "$SUM+$AVG" |bc -l|awk '{printf "%0.2f\n",$1}'`
                CN=$(( $CN + 1 ))
        done

        PEAK=`echo "$SUM/$CN"|bc -l|awk '{printf "%0.2f%\n",$1}'`
  if [ ${PEAK/.*/} -ge 60 ];then
    CPU_PA="<font color='red'><b>$PEAK</b></font>";
  else
    CPU_PA=$PEAK;
  fi

}

LOAD ()
{

        SUM=0
        CN=0
        TOTAL_CORE=`grep -c processor /proc/cpuinfo`
        for i in $SAR_FILES
        do
                AVG=`sar -i 60 -q -f $i |sed '/runq-sz\|Average\|Linux\|^$/d'|awk '{print $4}'|sort -n|tail -10 |awk '{sum=sum+$1 } END {printf "%0.2f \n", sum/NR}'`
                SUM=`echo "$SUM+$AVG" |bc -l|awk '{printf "%0.2f\n",$1}'`
                CN=$(( $CN + 1 ))
        done

        PEAK=`echo "$SUM/$CN"|bc -l|awk '{printf "%0.2f",$1}'`
  LIMIT=`echo "$TOTAL_CORE*0.80"|bc -l`

  if [ `echo "${PEAK} > ${LIMIT}"|bc` -eq 1 ]; then
    LOAD_PA="<font color='red'><b>$PEAK</b></font>";
  else
    LOAD_PA=$PEAK;
  fi

}


SWAP ()
{
        SUM=0
        CN=0
        PAGE_SIZE=`getconf PAGESIZE`
        
        for i in $SAR_FILES
        do
                AVG=`sar -i 60 -W -f $i |sed '/pswpin\|Average\|Linux\|^$/d'|sort -rn -k3|head -n 10|awk '{sum=sum+$3} END {printf "%0.2f \n", sum/NR}'`
                SUM=`echo "$SUM+$AVG" |bc -l|awk '{printf "%d\n",$1}'`
                CN=$(( $CN + 1 ))

        done

        if [ "$SUM" == "0" ];then
                SWAP_AP=0;
        else
                PEAK=`echo "$SUM/$CN"|bc -l|awk '{printf "%0.2fkbyte\n",$1*4}'`
                SWAP_AP=$PEAK;
        fi
}

NETWORK ()
{

		MAX_RX=0
    MAX_TX=0
    for i in $SAR_FILES
    do
			AVG=(`sar -i 60 -n DEV -f $i |sed '/Linux\|IFACE\|Average\|lo\|tunl/d'| awk '
					{ rx[++d]=$5; tx[d]=$6;inf[d]=$2;}
					END {
					asort(rx,srx)
					asort(tx,stx)
					max_rx = srx[d-1];
					max_tx = stx[d-1];
					for ( i=1;i<d;i++){
					if ( rx[i] == max_rx )
					max_rx_inf=inf[i];
					if ( tx[i] == max_tx )
					max_tx_inf=inf[i];
					}
					printf "%s:%0.2f %s:%0.2f\n" ,max_rx_inf,max_rx*8, max_tx_inf,max_tx*8;
					}'`)

				if [ `echo "${AVG[0]#*:} > ${MAX_RX}"|bc` -eq 1 ];then
					MAX_RX=${AVG[0]#*:}
					MAX_RX_INF=${AVG[0]%:*}
				fi
				if [ `echo "${AVG[1]#*:} > ${MAX_TX}"|bc` -eq 1 ];then
					MAX_TX=${AVG[1]#*:}
					MAX_TX_INF=${AVG[1]%:*}
				fi
			done

		if [ $SAR_VER -ge 9 ];then
			RX_PA=`echo "${MAX_RX}" | awk '{printf "%0.2fMbps",$1/1024}'`;
			TX_PA=`echo "${MAX_TX}" | awk '{printf "%0.2fMbps",$1/1024}'`;
		else
			RX_PA=`echo "${MAX_RX}" | awk '{printf "%0.2fMbps",$1/1024/1024}'`;
			TX_PA=`echo "${MAX_TX}" | awk '{printf "%0.2fMbps",$1/1024/1024}'`;
		fi

		if [[ $MAX_RX_INF =~ bond ]];then
			if grep -q fault-tolerance /proc/net/bonding/$MAX_RX_INF ; then
					RX_LIMIT=$(ethtool `awk '/Currently Active Slave:/ {print $NF}' /proc/net/bonding/$MAX_RX_INF`|awk -F':' '/Speed:/ {print $NF}'|egrep -o [0-9]+)
			else
					RX_LIMIT=`awk '/Speed:/ && !/Unknown/ {print $2}' /proc/net/bonding/$MAX_RX_INF|head -n1`
					RX_LIMIT=$(( $RX_LIMIT + RX_LIMIT ))
			fi

		else
			RX_LIMIT=`ethtool $MAX_RX_INF|awk -F':' '/Speed:/ {print $NF}'|egrep -o [0-9]+`
		fi

		if [[ $MAX_TX_INF =~ bond ]];then
			if grep -q fault-tolerance /proc/net/bonding/$MAX_TX_INF ; then
				TX_LIMIT=$(ethtool `awk '/Currently Active Slave:/ {print $NF}' /proc/net/bonding/$MAX_TX_INF`|awk -F':' '/Speed:/ {print $NF}'|egrep -o [0-9]+)
			else
				TX_LIMIT=`awk '/Speed:/ && !/Unknown/ {print $2}' /proc/net/bonding/$MAX_TX_INF|head -n1`
				TX_LIMIT=$(( $TX_LIMIT + TX_LIMIT ))
			fi

		else
			TX_LIMIT=`ethtool $MAX_TX_INF|awk -F':' '/Speed:/ {print $NF}'|egrep -o [0-9]+`
		fi

		if [ "$SYSTEM_TYPE" == "PM" ];then
				TX_LIMIT=`echo "$TX_LIMIT*0.75"|bc`
				RX_LIMIT=`echo "$RX_LIMIT*0.75"|bc`
		else
				TX_LIMIT=`echo "$TX_LIMIT*0.25"|bc`
				RX_LIMIT=`echo "$RX_LIMIT*0.25"|bc`
		fi

		if [ `echo "${RX_PA/Mbps/} > $RX_LIMIT "|bc` -eq 1 ]; then
				 RX_PA="<font color='red'><b>$RX_PA</b></font>";
		fi
		if [ `echo "${TX_PA/Mbps/} > $TX_LIMIT "|bc` -eq 1 ]; then
				 TX_PA="<font color='red'><b>$TX_PA</b></font>";
		fi


}

DISK() {

DF=`df -TlhP|awk '$1 ~ /dev/ {sub("%",""); if($6>90) USE="<font color=\"red\">"$(NF-1)"%</font>"; else USE=$(NF-1)"%";print $NF": "$4"/"$3 "("USE")"}'|paste -s -d','`

}




## EXECUTE
MINING_SYSTEM_TYPE
CPU
LOAD
SWAP
NETWORK
DISK
echo "$HOSTNAME|$CPU_PA|$LOAD_PA/$TOTAL_CORE|$SWAP_AP|$RX_PA|$TX_PA|$DF"
