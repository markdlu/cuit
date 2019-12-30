#!/bin/bash
#       Name
#          restore_rman.sh
#       Purpose
#          To restore database  
#       Usage
#          rman_restore.sh <DBNAME> 
#######################################
# Modify by     Date        Reason
# Mark Lu     12/07/2017    init 
#
###########################################################

export V_PASSWD=`grep "rman1t:rman" ~/.getpw.lst|cut -f 3 -d ':'`

PROGRAM_NAME=${0##*/}
if (( $# == 0 ))
then
echo " \n\tUsage : ${PROGRAM_NAME} <Database Name> " 
echo
exit
fi

. ${HOME}/set_env.sh $1
day=`date +%d`

time=`date '+%m%d%y%H%M%S'`
cmdfile=restore_${ORACLE_SID}_$time.rcv
DATE_DIR=`date +"%Y_%m_%d"`
PROGRAM_NAME=$(basename $0); export PROGRAM_NAME
DBName=${ORACLE_SID}; export DBName

cat << EOF > $cmdfile
connect target /
connect catalog rman/${V_PASSWD}@rman1t
run {
restore controlfile;
restore database;
recover database;
alter database open resetlogs;
}
EOF

rman  cmdfile $cmdfile 


