#!/bin/bash
#
#  this is local apply script been called by master scripts to apply PSU patch quartly  
#  this is assuming each databae instance on each host only
#
#  V1 -- Mark Lu initialized on Nov 6, 2017 
#
#####################################################
if [ -e ~/.bash_profile ]
then
. ~/.bash_profile
fi 
. /tmp/set_env.sh $1

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`
MAILINGLIST='ml4147@columbia.edu'
export ORACLE_SID=$1
export GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2017-12.1.0.2.Q4db.tar.gz
V_PASSWD=`grep "rman1p:rman" ~/.getpw.lst|cut -f 3 -d ':'`
cmdfile=/tmp/rman_psubk_${ORACLE_SID}_rollback.rcv
msglog=/tmp/rman_psubk_${ORACLE_SID}_rollback.log
#export GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2017-12.1.0.Q4db.tar.gz
host=`uname -n`
#MAILINGLIST='oradmin@columbia.edu,sp3114@columbia.edu'


function prepare_rollback
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Prepare rollback starting..."    >> $LOGFILE 2>&1
if [ ! -e  ${ORACLE_HOME}_bk ]
then
echo "No Backup Oracle Home found, do nothing, exits" >> $LOGFILE 2>&1
exit
fi
$SQLDBA  <<EOF  > ${LOGFILE}_preparecoldbackup.txt
set heading off 
set feedback off
set linesize 1000
select VALUE from  v\$parameter where name ='control_files';
select file_name from dba_data_files;
select member from v\$logfile;
EOF
cat  ${LOGFILE}_preparecoldbackup.txt |grep -v .ctl >  ${LOGFILE}_preparecoldbackup2.txt
cat  ${LOGFILE}_preparecoldbackup.txt |grep  .ctl |cut -d ',' -f1 >>  ${LOGFILE}_preparecoldbackup2.txt
cat  ${LOGFILE}_preparecoldbackup.txt |grep  .ctl |cut -d ',' -f2 >>  ${LOGFILE}_preparecoldbackup2.txt
echo "Prepare Cold backup Ended..."    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
}

function rollback_OH_DB
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE
echo "Rollback Oracle_Home and Database Starting...  "   >> $LOGFILE 2>&1
if [ ! -e ${LOGFILE}_preparecoldbackup2.txt ]
then
end_blackout;   >> $LOGFILE 2>&1
echo "No ${LOGFILE}_preparecoldbackup2.txt available, do nothing, exits" >> $LOGFILE 2>&1
exit
fi 
cp -rp  $ORACLE_HOME/dbs /tmp/${ORACLE_SID}_dbs    >> $LOGFILE 2>&1
cp -rp  $ORACLE_HOME/network /tmp/${ORACLE_SID}_network    >> $LOGFILE 2>&1
rm -rf $ORACLE_HOME
if [ -d  ${ORACLE_HOME}_bk ]
then
mv  ${ORACLE_HOME}_bk  $ORACLE_HOME >> $LOGFILE 2>&1
fi
for file in `cat  ${LOGFILE}_preparecoldbackup2.txt`; do >> $LOGFILE 2>&1
cp -rp ${file}-bk $file   >> $LOGFILE 2>&1
done
if [ -e ${LOGFILE}_preparecoldbackup.txt ]
then
mv ${LOGFILE}_preparecoldbackup.txt ${LOGFILE}_preparecoldbackup.txt-OLD
fi
if [ -e ${LOGFILE}_preparecoldbackup2.txt ]
then
mv  ${LOGFILE}_preparecoldbackup2.txt  ${LOGFILE}_preparecoldbackup2.txt-OLD
fi
echo "Rollback Oracle_Home and Database Ended..."    >> $LOGFILE 2>&1
date >> $LOGFILE
echo "  "    >> $LOGFILE 2>&1
}


function rollback_OH_DB_RMAN
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE
echo "Rollback Oracle_Home and Database Starting...  "   >> $LOGFILE 2>&1
if [ ! -e ${LOGFILE}_preparecoldbackup2.txt ]
then
echo "No ${LOGFILE}_preparecoldbackup2.txt available, do nothing, exits" >> $LOGFILE 2>&1
exit
fi
#for OH
cp -rp  $ORACLE_HOME/dbs /tmp/${ORACLE_SID}_dbs    >> $LOGFILE 2>&1
cp -rp  $ORACLE_HOME/network /tmp/${ORACLE_SID}_network    >> $LOGFILE 2>&1
rm -rf $ORACLE_HOME
if [ -d  ${ORACLE_HOME}_bk ]
then
mv  ${ORACLE_HOME}_bk  $ORACLE_HOME >> $LOGFILE 2>&1
fi
#for DB
$SQLDBA  <<EOF  >> $LOGFILE 2>&1
set heading off
shutdown abort;
startup nomount;
quit
EOF
if [ -e $cmdfile ]
then
mv $cmdfile $cmdfile-OLD
fi 
SCN=`cat /tmp/${ORACLE_SID}_scn`
cat <<EOF > $cmdfile
connect target /
connect catalog rman/${V_PASSWD}@rman1p
run {
ALLOCATE  CHANNEL ch1 DEVICE TYPE disk;
ALLOCATE  CHANNEL ch2 DEVICE TYPE disk;
ALLOCATE  CHANNEL ch3 DEVICE TYPE disk;
ALLOCATE  CHANNEL ch4 DEVICE TYPE disk;
restore controlfile from TAG "forpsupatch";
alter database mount;
restore database from  TAG "forpsupatch";
recover database until scn ${SCN};
alter database open resetlogs;
release channel ch1;
release channel ch2;
release channel ch3;
release channel ch4;
}
EOF
sleep 10
rman  cmdfile $cmdfile log $msglog
tail -20  $msglog >> $LOGFILE
mv $msglog $msglog-OLD
mv $cmdfile $cmdfile-OLD
echo "Rollback Oracle_Home and Database Ended..."    >> $LOGFILE 2>&1
date >> $LOGFILE
echo "  "    >> $LOGFILE 2>&1
}


function do_coldbackup
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Cold backup starting..."   >> $LOGFILE 2>&1
for file in `cat  ${LOGFILE}_preparecoldbackup2.txt`; do >> $LOGFILE 2>&1
cp -rp $file ${file}-bk    >> $LOGFILE 2>&1
done
echo "Cold backup Ended..."    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
}

function stop_db 
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Stopping DB..."   >> $LOGFILE 2>&1
$SQLDBA  <<EOF  >> $LOGFILE 2>&1
set heading off
shutdown abort;
startup;
alter database flashback off;
shutdown immediate;
quit
EOF
date >> $LOGFILE 
}

function start_db 
{
date >> $LOGFILE 
echo "Starting DB..."   >> $LOGFILE 2>&1
$SQLDBA  <<EOF  >> $LOGFILE 2>&1 
set heading off
startup;
alter database flashback on;
quit
EOF
date >> $LOGFILE 
}

function run_sql 
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Apply SQL on $ORACLE_SID starting..."   >> $LOGFILE 2>&1
sh $ORACLE_HOME/OPatch/datapatch -verbose   >> $LOGFILE 2>&1 
echo "Apply SQL on $ORACLE_SID Ended..."   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
}

function verify_version 
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Verify Patch Status Starting..."   >> $LOGFILE 2>&1
$SQLDBA  <<EOF  > ${LOGFILE}_verify 
set heading off
SET LINESIZE 500
SET PAGESIZE 1000
SET SERVEROUT ON
SET LONG 2000000
COLUMN action_time FORMAT A20
COLUMN action FORMAT A10
COLUMN bundle_series FORMAT A10
COLUMN comments FORMAT A30
COLUMN description FORMAT A45
COLUMN namespace FORMAT A20
COLUMN status FORMAT A10
COLUMN version FORMAT A10

select instance_name from v\$instance;
SELECT TO_CHAR(action_time, 'DD-MON-YYYY HH24:MI:SS') AS action_time,
 action,
 status,
 description,
 version,
 patch_id,
 bundle_series
 FROM   sys.dba_registry_sqlpatch
 ORDER by action_time;
EOF
echo "Verify Patch Status Ended..."   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
}



function apply_patch 
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Apply PSU on $ORACLE_HOME Starting..."   >> $LOGFILE 2>&1
cd $ORACLE_HOME     >> $LOGFILE 2>&1 
cd ..
if [ -d ${ORACLE_HOME}_bk ]; then
rm -rf  ${ORACLE_HOME}_bk
fi 
sleep 5
mv $ORACLE_HOME ${ORACLE_HOME}_bk  >> $LOGFILE 2>&1 
tar -xvf ${GoldenImageFile}
$ORACLE_HOME/bin/relink all   >> $LOGFILE 2>&1
mv $ORACLE_HOME/dbs $ORACLE_HOME/dbs-bk   >> $LOGFILE 2>&1
cp -rp ${ORACLE_HOME}_bk/dbs $ORACLE_HOME/.   >> $LOGFILE 2>&1
mv $ORACLE_HOME/network/admin $ORACLE_HOME/network/admin-bk  >> $LOGFILE 2>&1
cp -rp ${ORACLE_HOME}_bk/network/admin $ORACLE_HOME/network/.  >> $LOGFILE 2>&1
echo "Apply PSU on $ORACLE_HOME Ended..."   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
}

function restart_listener
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Restart listener Starting... "   >> $LOGFILE 2>&1
lsn=` ps -ef |grep lsn |grep -v grep |awk  '{print $9}'`  >> $LOGFILE   2>&1
echo ${lsn}                              >> $LOGFILE   2>&1
$ORACLE_HOME/bin/lsnrctl stop ${lsn}    >> $LOGFILE  2>&1      
$ORACLE_HOME/bin/lsnrctl start ${lsn}   >> $LOGFILE  2>&1
$ORACLE_HOME/bin/lsnrctl status ${lsn}  >>  $LOGFILE 2>&1
echo "Restart listener Ended... "   >> $LOGFILE 2>&1
date >> $LOGFILE 
}


function begin_blackout
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "beging blackout on node leve on $host "   >> $LOGFILE 2>&1
OEMPATH=`cat /etc/oratab |grep agent  |grep -v '#'  |cut -d: -f2`  >> $LOGFILE 2>&1
echo "$OEMPATH"
$OEMPATH/bin/emctl start blackout myblackout -nodeLevel >> $LOGFILE 2>&1 
$OEMPATH/bin/emctl status blackout >> $LOGFILE 2>&1 
date >> $LOGFILE 
}

function end_blackout
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "End blackout on node leve on $host "   >> $LOGFILE 2>&1
OEMPATH=`cat /etc/oratab |grep agent |grep -v '#' |cut -d: -f2`  >> $LOGFILE 2>&1
$OEMPATH/bin/emctl stop blackout myblackout >> $LOGFILE 2>&1 
sleep 10
$OEMPATH/bin/emctl status blackout >> $LOGFILE 2>&1 
date >> $LOGFILE 
}


#main

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQL_DBA

LOGFILE=/tmp/apply_psu_local_${ORACLE_SID}_rollback.log
echo ${ORACLE_SID} > $LOGFILE

prepare_rollback;
begin_blackout;
stop_db;
rollback_OH_DB_RMAN
start_db;
restart_listener;
verify_version;
end_blackout;

