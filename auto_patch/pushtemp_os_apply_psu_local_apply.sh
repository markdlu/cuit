#!/bin/bash

SCRIPTHOME=/oradmin/common/scripts/PSU

mv /tmp/list_temp.txt.out /tmp/list_temp.txt.out-bk1 
#for  i in `cat ./oracle_host_list.txt` ; do
for  i in `cat ./temp_host_list.txt` ; do
echo $i
ssh $i " if [ ! -d $SCRIPTHOME ]; then mkdir -p $SCRIPTHOME; fi"
ssh $i  'if [ `grep ^PSU /etc/oratab |wc -l`  -eq 1 ] ; then  echo "yes psu"  ;else `echo 'PSU:Y' >> /etc/oratab`;fi;' 
scp ./os_apply_psu_local_apply.sh $i:$SCRIPTHOME/.  
done | tee -a /tmp/list_temp.txt.out 2>&1
        

