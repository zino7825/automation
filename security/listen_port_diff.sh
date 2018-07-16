# daily check : listen port and binary diff ( rhel/centos )
# find -mtime -1 : daily check modifed binary
# create by zino.k
osver=`sed -r 's/.*release ([0-9]).*/\1/' /etc/redhat-release`

while read proto port prog pid
do
  if [ "$prog" == "-" ];then
    PROG=(`lsof -n -i${prot}:${port}|grep 'LISTEN'|head -n1|awk '{print $1,$2}'`)
    if [ "$PROG" != "" ];then
      prog=${PROG[0]}; pid=${PROG[1]}
    fi
  fi
  if [ "$prog" != "-" ];then
    fname=`readlink /proc/$pid/exe|grep -v '(deleted)'`
    if [ "$fname" != "" ];then
      if [ "`find $fname -mtime -1`" != "" ];then
        md5=`md5sum /proc/$pid/exe|awk '{print $1}'`
        #Save db by web api
        #curl -H "User-Agent: diff/1.0" -X POST -F "hostname=${HOSTNAME}" -F" proto=${proto}" -F "port=${port}" -F "procs=${prog}" -F "fpath=${fname}" -F "md5=${md5}" http://exmaple.com/diff
        echo "${HOSTNAME}:${proto}:${port}:${prog}:${fname}:${md5}"
        # check virus 
        # curl -s -k -d "apikey=xxxx&resource=$md5" https://www.virustotal.com/vtapi/v2/file/report
      fi
    fi
  fi
done <<< "$(
ss -utnlp|sed '1d' |awk -v OS=$osver '
{
  if($0 != "") {
    if(OS>5){
      gsub(/.*:/,"",$5);
      if ($7 == "") {
       print $1,$5,"- -"
      } else {
        A="";for(i=7;i<=NF;i++){A=A$i}
        gsub(/users:\(\(|pid=|"/,"",A);split(A,PROG,",");print $1,$5,PROG[1],PROG[2]
      }
    } else {
      gsub(/.*\:/,"",$4);
      if($6 == "") {
        $6="-";print $1,$4,"- -"
      } else {
        A="";for(i=6;i<=NF;i++){A=A$i}
        gsub(/users:\(\(|"/,"",A);split(A,PROG,",");print $1,$4,PROG[1],PROG[2]
      }
    }
  }
}'|sort|uniq)"

