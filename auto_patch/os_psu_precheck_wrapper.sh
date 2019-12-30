#!/bin/bash
if [ -f /oradmin/common/scripts/PSU/os_apply_psu_local_apply.sh ]
then
sh /oradmin/common/scripts/PSU/os_apply_psu_local_apply.sh precheck 
fi

if [ $? = 0 ]
then
echo 0
else
echo 1
fi
