#!/bin/bash
#
#  this is local precheck script been called by master scripts to apply PSU patch quartly  
#  this is assuming each databae instance on each host only
#
#  V1 -- Mark Lu initialized on Dec 01, 2017 
#        Added checking oracle binary group is cudba or not on March 22, 2018
#
#####################################################
if [ -e  ~/.bash_profile ]
then
. ~/.bash_profile
fi 

. /tmp/set_env.sh $1

GROUP="cudba"

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`
MAILINGLIST='ml4147@columbia.edu'
export ORACLE_SID=$1
host=`uname -n`
#MAILINGLIST='oradmin@columbia.edu,sp3114@columbia.edu'


#---------------------------------------------------------------------------------------#
#this is prechecking Database control file format and patch version already in database.# 
#---------------------------------------------------------------------------------------#
function precheck_DB
{
$SQLDBA  <<EOF  >> ${LOGFILE} 2>&1
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
select value  from v\$parameter where name ='control_files';
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

$SQLDBA  <<EOF  > /dev/null  
set heading off
SET LINESIZE 500
SET PAGESIZE 0 
SET SERVEROUT ON
SET LONG 2000000
spool /tmp/patchlist1_$ORACLE_SID.txt
select xmltransform(DBMS_QOPATCH.GET_OPATCH_LIST,dbms_qopatch.get_opatch_xslt) "Patch installed?" from dual;
spool off
EOF

grep "Patch(sqlpatch)"  /tmp/patchlist1_$ORACLE_SID.txt > /tmp/patchlist2_$ORACLE_SID.txt 
mv /tmp/patchlist1_$ORACLE_SID.txt /tmp/patchlist1_$ORACLE_SID.txt-OLD
cat /tmp/patchlist2_$ORACLE_SID.txt |cut -d: -f1 > /tmp/patchlist3_$ORACLE_SID.txt
mv /tmp/patchlist2_$ORACLE_SID.txt /tmp/patchlist2_$ORACLE_SID.txt-OLD
cat /tmp/patchlist3_$ORACLE_SID.txt |cut -d ' ' -f2 > /tmp/patchlist_$ORACLE_SID.txt
mv  /tmp/patchlist3_$ORACLE_SID.txt  /tmp/patchlist3_$ORACLE_SID.txt-OLD


#echo "7777778788" >>  /tmp/patchlist_${ORACLE_SID}.txt

PT="1"
if [ -e  /tmp/patchlist_${ORACLE_SID}.txt ] || [ -e  /tmp/patchlist_GI.txt ]
then
PT=`ksh "comm -23 <(sort /tmp/patchlist_${ORACLE_SID}.txt) <(sort /tmp/patchlist_GI.txt)"|wc -l`
#PT=`comm -23  /tmp/patchlist_${ORACLE_SID}.txt /tmp/patchlist_GI.txt |wc -l`
echo "#pt 0 is expected, otherwise means more patchs on target DB home than golden image"  >> ${LOGFILE} 2>&1
echo "PT:"$PT >> ${LOGFILE} 2>&1
else echo "PT:"$PT >> ${LOGFILE} 2>&1
fi
}

#--------------------------------------------------------------------#
#this is prechecking how many database instances on same Oracle_Home.#
#--------------------------------------------------------------------#
function precheck_oratab
{
if [ -e /tmp/oratab_temp2_${ORACLE_SID}.txt ]
then
mv  /tmp/oratab_temp2_${ORACLE_SID}.txt  /tmp/oratab_temp2_${ORACLE_SID}.txt-OLD
fi
cat /etc/oratab > /tmp/oratab_temp.txt
for line in `cat  /tmp/oratab_temp.txt |grep $ORACLE_HOME |grep Y |cut -d: -f2` ; do
if [ "$line" = "$ORACLE_HOME" ]
then
echo "$line" >> /tmp/oratab_temp2_${ORACLE_SID}.txt 
fi
done
COUNT=`cat  /tmp/oratab_temp2_${ORACLE_SID}.txt |wc -l`
echo "ORACLE_HOME:"$COUNT  >> $LOGFILE
}


#---------------------------------------------------#
#this is prechecking Oracle_Home path for given SID.#
#---------------------------------------------------#
function precheck_OHPATH
{
if [ -e /tmp/oratab_temp2_OHPATH_${ORACLE_SID}.txt ]
then
mv  /tmp/oratab_temp2_OHPATH_${ORACLE_SID}.txt /tmp/oratab_temp2_OHPATH_${ORACLE_SID}.txt-OLD
fi 
cat /etc/oratab > /tmp/oratab_temp.txt
 for line in `cat  /tmp/oratab_temp.txt |grep $ORACLE_SID ` ; do
 sid=`echo $line  |cut -d: -f1`
 OHPATH=`echo $line |cut -d: -f2`
 if [ "$sid" = "$ORACLE_SID" ]
 then
 echo "$OHPATH" >> /tmp/oratab_temp2_OHPATH_${ORACLE_SID}.txt
 fi
 done

OHPATH2=`cat /tmp/oratab_temp2_OHPATH_${ORACLE_SID}.txt` 
echo "OHPATH:"$OHPATH2 >> $LOGFILE

}

function precheck_group
{
gflag=`id |grep $GROUP |wc -l `
if [ $gflag -eq 1 ]
then
echo "GROUP:cudba" >> ${LOGFILE} 2>&1
else
echo "GROUP:bad" >> ${LOGFILE} 2>&1
fi 
}


function precheck_rmandir
{
if [ ! -e  /oradmin/common/scripts/rman_hot_backup.sh ]
then echo "RMANDIR:null"  >> $LOGFILE
fi
RMANDIR=`grep orabackup /oradmin/common/scripts/rman_hot_backup.sh | cut -d / -f2 |head -1`   
RMANDIR2="/$RMANDIR"  
echo "RMANDIR:${RMANDIR2}"  >> ${LOGFILE} 2>&1 
}

#main

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQLDBA

LOGFILE=/tmp/apply_psu_local_${ORACLE_SID}_precheck.log
echo $ORACLE_SID > $LOGFILE

precheck_DB;
precheck_oratab;
precheck_OHPATH;
#precheck_rmandir;
precheck_group;


