#!/bin/bash

SCRIPTNAME=/oradmin/common/scripts/PSU/os_psu_precheck_wrapper.sh

for  i in `cat ./oracle_host_list.txt` ; do
#for  i in `cat ./testhost_list.txt` ; do
scp ./os_psu_precheck_wrapper.sh $i:/oradmin/common/scripts/PSU/.
ssh $i  " if [ -f $SCRIPTNAME ] ; then $SCRIPTNAME ;fi" 
done 
        

