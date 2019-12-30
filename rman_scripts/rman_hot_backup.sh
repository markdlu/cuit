#!/bin/ksh
#       Name
#          rman_hot_backup.sh
#       Purpose
#          To perform Rman Hot backup of Oracle database
#       Usage
#          rman_hot_backup.sh <DBNAME> <INCREMENTAL_LEVEL>
#######################################
# Modify by     Date        Reason
# Mark Lu     12/06/2017   change form mkdir to mkdir -p
#
###########################################################
# To check if the Database Argument is Supplied

export V_PASSWD=`grep "rman1t:rman" ~/.getpw.lst|cut -f 3 -d ':'`

PROGRAM_NAME=${0##*/}
if (( $# == 0 ))
then
print " \n\tUsage : ${PROGRAM_NAME} <Database Name> <Backup Level>"
print
exit
fi

###################
# Set Environment
. /usr/local/lib/service/cuorsa/.profile
. ${HOME}/set_env.sh $1
day=`date +%d`
############### Set script specific variables  ########################

time=`date '+%m%d%y%H%M%S'`
cmdfile=$DBA_DB_LOG/rman_hot_backup_${2}_${ORACLE_SID}_$time.rcv
msglog=$DBA_DB_LOG/rman_hot_backup_${2}_${ORACLE_SID}_$time.log
TAG=hot_bkup_${ORACLE_SID}_`date '+%m%d%y%H%M'`
ARCH_TAG=arch_bkup_${ORACLE_SID}_`date '+%m%d%y%H%M'`
DATE_DIR=`date +"%Y_%m_%d"`
############## Tracking Script Variables #################################
PROGRAM_NAME=$(basename $0); export PROGRAM_NAME
DBName=${ORACLE_SID}; export DBName
EVENT_ID=`date '+%Y%m%d%H%M%S'`${RANDOM}; export EVENT_ID
case $2 in  0) BKUP_TYPE=Full;; 1) BKUP_TYPE=Incremental;; *) BKUP_TYPE=Full ;; esac
##########################################################################
############## Call Tracking Script START Event ##########################
# Parms:   1        2          3      4       5      6       7     8            9
# Parms: EventNm  Type     State DBServer DBname DBtype  RtCode ScriptName    EVENT_ID
$DBA_BIN/post_event.sh  \
      HOT_BACKUP ${BKUP_TYPE} START $DBName $DBName ORACLE    0 $PROGRAM_NAME $EVENT_ID
##########################################################################
############### Manage backup subdirectory #############################
if [ ! -d "/orabackupc/$ORACLE_SID/data/$DATE_DIR" ]; then
  mkdir -p /orabackupc/$ORACLE_SID/data/$DATE_DIR
fi
if [ ! -d "/orabackupc/$ORACLE_SID/logs/$DATE_DIR" ]; then
  mkdir -p /orabackupc/$ORACLE_SID/logs/$DATE_DIR
fi
############### Generate the Rman command file  ########################
cat << EOF > $cmdfile
connect target /
connect catalog rman/${V_PASSWD}@rman1t
run {
   allocate channel fs1 type disk format=
          '/orabackupc/$ORACLE_SID/data/$DATE_DIR/${day}_1_%U';
   allocate channel fs2 type disk format=
          '/orabackupc/$ORACLE_SID/data/$DATE_DIR/${day}_2_%U';
   allocate channel fs3 type disk format=
          '/orabackupc/$ORACLE_SID/data/$DATE_DIR/${day}_3_%U';
   allocate channel fs4 type disk format=
          '/orabackupc/$ORACLE_SID/data/$DATE_DIR/${day}_4_%U';
CROSSCHECK ARCHIVELOG ALL;
backup filesperset=1 as BACKUPSET INCREMENTAL LEVEL $2 DATABASE TAG=$TAG include current controlfile;
release channel fs1;
release channel fs2;
release channel fs3;
release channel fs4;
}
run {
   allocate channel fs1 type disk format=
          '/orabackupc/$ORACLE_SID/logs/$DATE_DIR/${day}_1_%U';
   allocate channel fs2 type disk format=
          '/orabackupc/$ORACLE_SID/logs/$DATE_DIR/${day}_2_%U';
backup archivelog all delete input filesperset=10 TAG=$ARCH_TAG;
release channel fs1;
release channel fs2;
}
EOF

chmod 660 $cmdfile
##### Perform the backup  ##########
rman  cmdfile $cmdfile log $msglog

##### Remove old backup files and logs ######
find $DBA_DB_LOG -name "rman_hot_backup*" -mtime +29 -exec rm {} \;
#find /oraflash/$ORACLE_SID/rman/ -name "*" -mtime +1 -exec rm {} \;

##### Save SCN ######
#$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
#set pages 0 termout off trims on echo off
#spool /oraflash/$ORACLE_SID/rman/scn
#select max_next_change# from v\$backup_archivelog_summary;
#spool off
#exit
#EOF

ERRORNUM=`egrep '(ERROR|error|Error)' $msglog | wc -l`
if [ `expr ${ERRORNUM}` -gt `expr 0` ]
then
  mailx -s "${PROGRAM_NAME} failed for ${ORACLE_SID}" ci2176@columbia.edu <<-!
Below is the last 5 lines of the log file...

$(tail -5 $msglog)
#$(unix2dos < $msglog 2>/dev/null | uuencode ${msglog##*/}.txt)
!
fi
############## Call Tracking Script END Event ##########################
# Parms:   1        2          3      4       5      6       7     8            9
# Parms: EventNm  Type     State DBServer DBname DBtype  RtCode ScriptName    EVENT_ID
$DBA_BIN/post_event.sh  \
      HOT_BACKUP ${BKUP_TYPE} END $DBName $DBName ORACLE    0 $PROGRAM_NAME $EVENT_ID
##########################################################################
