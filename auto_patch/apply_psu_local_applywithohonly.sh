#!/bin/bash
#
#  this is local apply script been called by master scripts to apply PSU patch quartly  
#  this is assuming each databae instance on each host only
#
#  V1 -- Mark Lu initialized on Nov 6, 2017 
#
#  Modified By    Time         Reason
#  Mark Lu       12/05/2017    in cold backup, added checking for ${LOGFILE}_preparecoldbackup2.txt exists or not	
#
#####################################################
if [ -e  ~/.bash_profile ]
then
. ~/.bash_profile
fi 
. /tmp/set_env.sh $1

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`
ORACLE_SID=$1

GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2018-12.1.0.2.Q4db.tar.gz

V_PASSWD=`grep "rman1p:rman" ~/.getpw.lst|cut -f 3 -d ':'`
RMANDIR1=`grep orabackup /oradmin/common/scripts/rman_hot_backup.sh | cut -d / -f2 |head -1`
RMANDIR="/$RMANDIR1"
RMANBK_DIR="psubk"
cmdfile=/tmp/rman_psubk_${ORACLE_SID}.rcv
msglog=/tmp/rman_psubk_${ORACLE_SID}.log
host=`uname -n`
#MAILINGLIST='oradmin@columbia.edu,sp3114@columbia.edu'


function prepare_db_coldbackup
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Prepare Cold backup starting..."    >> $LOGFILE 2>&1
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

function do_db_rmanbackup
{
TAG="forpsupatch"
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE
echo "Prepare RMAN backup starting..."    >> $LOGFILE 2>&1
#to keep 1 more backup piece
if [ ! -d $RMANDIR/$ORACLE_SID/$RMANBK_DIR ]
then
mkdir -p $RMANDIR/$ORACLE_SID/$RMANBK_DIR
mkdir -p $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk
elif [ -d $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk ]
then
rm -rf $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk
mv $RMANDIR/$ORACLE_SID/$RMANBK_DIR $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk
mkdir -p $RMANDIR/$ORACLE_SID/$RMANBK_DIR
elif [ ! -d $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk ]
then
mv $RMANDIR/$ORACLE_SID/$RMANBK_DIR $RMANDIR/$ORACLE_SID/${RMANBK_DIR}_bk
mkdir -p $RMANDIR/$ORACLE_SID/$RMANBK_DIR
fi

cat << EOF > $cmdfile
connect target /
connect catalog rman/${V_PASSWD}@rman1p
run {
   allocate channel fs1 type disk format=
          '$RMANDIR/$ORACLE_SID/$RMANBK_DIR/datafile_1_%U';
   allocate channel fs2 type disk format=
          '$RMANDIR/$ORACLE_SID/$RMANBK_DIR/datafile_2_%U';
   allocate channel fs3 type disk format=
          '$RMANDIR/$ORACLE_SID/$RMANBK_DIR/datafile_3_%U';
   allocate channel fs4 type disk format=
          '$RMANDIR/$ORACLE_SID/$RMANBK_DIR/datafile_4_%U';
SET CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '$RMANDIR/$ORACLE_SID/$RMANBK_DIR/ctlf_%F';
CROSSCHECK ARCHIVELOG ALL;
backup filesperset=1 as BACKUPSET INCREMENTAL LEVEL 0 DATABASE TAG=$TAG include current controlfile;
release channel fs1;
release channel fs2;
release channel fs3;
release channel fs4;
}
EOF
rman  cmdfile $cmdfile log $msglog
tail -20  $msglog > ${msglog}_2
error=`grep -i rman- ${msglog}_2 |wc -l`
if [ $error != "0" ]
then
echo "some issues in rman backup... do nothing, -----Exits" >> $LOGFILE 2>&1
exit
fi
tail -20  $msglog >> $LOGFILE
mv $msglog $msglog-OLD
if [ -e  $cmdfile ]
then
grep -v catalog $cmdfile >  ${cmdfile}
fi 
mv $cmdfile ${cmdfile}-OLD
date >> $LOGFILE
echo "  "   >> $LOGFILE 2>&1
}


function do_coldbackup
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Cold backup starting..."   >> $LOGFILE 2>&1
if [ ! -e  ${LOGFILE}_preparecoldbackup2.txt ]
then
echo "No ${LOGFILE}_preparecoldbackup2.txt available, -----Exits" >> do >> $LOGFILE 2>&1
exit
fi
for file in `cat  ${LOGFILE}_preparecoldbackup2.txt`; do >> $LOGFILE 2>&1
cp -rp $file ${file}-bk    >> $LOGFILE 2>&1
done
echo "Cold backup Ended..."    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
if [ -e  ${LOGFILE}_preparecoldbackup.txt ]
then
mv ${LOGFILE}_preparecoldbackup.txt  ${LOGFILE}_preparecoldbackup.txt-OLD
fi
if [ -e ${LOGFILE}_preparecoldbackup2.txt ]
then
mv ${LOGFILE}_preparecoldbackup2.txt ${LOGFILE}_preparecoldbackup2.txt-OLD
fi
}

function stop_db 
{
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Stopping DB..."   >> $LOGFILE 2>&1
$SQLDBA  <<EOF  > /tmp/${ORACLE_SID}_scn
  set heading off
  SET LINESIZE 500
  SET PAGESIZE 1000
  SET SERVEROUT ON
  SET LONG 2000000
  SELECT TO_CHAR(CURRENT_SCN) FROM V\$DATABASE;
  quit
EOF
echo "M1"  >>  $LOGFILE 2>&1
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
 ORDER by patch_id;
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
if [ -d $ORACLE_HOME ]
then
mv $ORACLE_HOME ${ORACLE_HOME}_bk  >> $LOGFILE 2>&1 
fi
tar -pxvzf ${GoldenImageFile}
chmod 644 $ORACLE_HOME/lib/libsqlplus.so
$ORACLE_HOME/bin/relink all   >> $LOGFILE 2>&1
if [ -d $ORACLE_HOME/dbs ]
then
mv $ORACLE_HOME/dbs $ORACLE_HOME/dbs-bk   >> $LOGFILE 2>&1
fi
cp -rp ${ORACLE_HOME}_bk/dbs $ORACLE_HOME/.   >> $LOGFILE 2>&1
if [ -d $ORACLE_HOME/network/admin ]
then
mv $ORACLE_HOME/network/admin $ORACLE_HOME/network/admin-bk  >> $LOGFILE 2>&1
fi
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
lsn=` ps -ef |grep lsn |grep -v grep |grep -v dg |awk  '{print $9}'`  >> $LOGFILE   2>&1
echo ${lsn}                              >> $LOGFILE   2>&1
$ORACLE_HOME/bin/lsnrctl stop ${lsn}    >> $LOGFILE  2>&1      
$ORACLE_HOME/bin/lsnrctl start ${lsn}   >> $LOGFILE  2>&1
$ORACLE_HOME/bin/lsnrctl status ${lsn}  >>  $LOGFILE 2>&1
echo "Restart listener Ended... "   >> $LOGFILE 2>&1
date >> $LOGFILE 
}

function stop_listener
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE
echo "Stop listener Starting... "   >> $LOGFILE 2>&1
lsn=` ps -ef |grep lsn |grep -v grep |grep -v dg |awk  '{print $9}'`  >> $LOGFILE   2>&1
echo ${lsn}                              >> $LOGFILE   2>&1
$ORACLE_HOME/bin/lsnrctl stop ${lsn}    >> $LOGFILE  2>&1
$ORACLE_HOME/bin/lsnrctl status ${lsn}  >>  $LOGFILE 2>&1
echo "Stop listener Ended... "   >> $LOGFILE 2>&1
date >> $LOGFILE
}


function begin_blackout
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "beging blackout on node leve on $host "   >> $LOGFILE 2>&1
OEMPATH=`cat /etc/oratab |grep agent |cut -d: -f2`  >> $LOGFILE 2>&1
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
OEMPATH=`cat /etc/oratab |grep agent |cut -d: -f2`  >> $LOGFILE 2>&1
$OEMPATH/bin/emctl stop blackout myblackout >> $LOGFILE 2>&1 
sleep 10
$OEMPATH/bin/emctl status blackout >> $LOGFILE 2>&1 
date >> $LOGFILE 
}


#main

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQL_DBA

LOGFILE=/tmp/apply_psu_local_${ORACLE_SID}_applywithohonly.log
echo "${ORACLE_SID}" > $LOGFILE

#do_db_rmanbackup;
begin_blackout;
sleep 20;
#prepare_db_coldbackup;
#stop_listener;
stop_db;
##do_coldbackup;
apply_patch;
start_db;
#run_sql
restart_listener;
verify_version;
sleep 10
end_blackout;
