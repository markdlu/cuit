#!/bin/bash

SCRIPTHOME=/oradmin/common/scripts/PSU

#for  i in `cat ./new_host.txt` ; do
for  i in ppmarklutest01 ; do
echo $i
ssh $i " if [ ! -d $SCRIPTHOME ]; then mkdir -p $SCRIPTHOME; fi"
ssh $i  'if [ `grep ^PSU /etc/oratab |wc -l`  -eq 1 ] ; then  echo "yes psu"  ;else `echo 'PSU:Y' >> /etc/oratab`;fi;' 
scp ./os_psu_precheck_wrapper.sh $i:$SCRIPTHOME/.  
done 
        

