#!/bin/bash
#---------------------------------------------------------------------------------------------------
# Program:      apply_psu_q4_2017.sh 
#
# Purpose:      To apply quarterly PSU patch automatically
#
# Author:       Mark Lu 
# Date:         11/06/2017
# Version:      1.1
#
# Modified by           Date            Reason
# ---------------       ----------      ------------------------------------------------
# Mark Lu               12/02/2017      added precheck for Oracle_Home and Host      
# Mark Lu               12/06/2017      more enhancement 
# Mark Lu               01/11/2017      add condition for checking /orabase 
#
#####################################################
. ~/.bash_profile

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`  

#GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2018-12.1.0-2.0.Q1db.tar.gz
#GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2018-12.1.0.Q1db.tar.gz
GoldenImageFile=/kickstart/local_packages/oracle/Linux/x86-64/2018-12.1.0.2.Q1db.tar.gz

#OHPATHGI="/orabase/product/12.1.0"   #this is for oracle home must match the Golden Image
#OHPATHGI="/orabase/product/12.1.0/2.0"   #this is for oracle home must match the Golden Image
OHPATHGI="/orabase/product/12.1.0.2"   #this is for oracle home must match the Golden Image

OHSIZEGI=10000  #this is for mb size for /orabase must have
DSF=70  #this is for each mount point needs 50% free in order to do cold backup
PATCHVERSION="12.1.0.2.180116"
CTLFORMAT=".ctl"
LSNPROCESS=tnslsnr
PNAME=${0##*/}
export SCRIPTHOME=/oradmin/common/scripts/PSU
export HOST=`echo $1|tr [:upper:] [:lower:]`
export ORACLE_SID=`echo $2|tr [:upper:] [:lower:]`
export ACTION=`echo $3|tr [:upper:] [:lower:]`
export EMAIL=`echo $4|tr [:upper:] [:lower:]`
MAILINGLIST=${EMAIL}@columbia.edu

function f_usage
{
#this function will display the usage requirements for the script
    printf "

 PARAM 1 - HOST Name
 PARAM 2 - Database Instance Name
 PARAM 3 - Action [ precheck | apply | rollback ]
 PARAM 4 - Email [UNI] 

 Usage: $PNAME [HOST_name]   [Database_Name]  [ precheck|apply|rollback] [Uni] 
    "
    exit 1
}
function pre_check_OH
{
#check if the target instance is not up, exits
DBUP=`ssh $HOST "ps -eo args|grep ora_pmon_${ORACLE_SID}|grep -v grep|cut -d_ -f3|sed 's/ //g'"`   >> ${LOGFILE} 2>&1
if [ "$DBUP" == "${ORACLE_SID}" ]
then echo "DB $ORACLE_SID is up on $HOST, -----------PASSED" |tee -a $LOGFILE
else echo " ${ORACLE_SID} is Not up on $HOST, do nothing, ------------Exits..."  |tee -a $LOGFILE
email_log
exit
fi
#check if the target listener is not up, exits
LSNUPCONT=`ssh $HOST "ps -eo args|grep $LSNPROCESS|grep -v grep |grep -v dg | wc -l" `   >> ${LOGFILE} 2>&1
if [ "$LSNUPCONT" = "1" ]
then echo "Listener is up on $HOST, -----------PASSED" |tee -a $LOGFILE
else echo " listener is Not up on $HOST, do nothing, ------------Exits..."  |tee -a $LOGFILE
email_log
exit
fi
#step for copying file over target host
ssh $HOST  " if [ ! -d  $SCRIPTHOME ]; then mkdir -p  $SCRIPTHOME; fi"   >> ${LOGFILE} 2>&1
scp ./apply_psu_local_precheck.sh  $HOST:$SCRIPTHOME/.  >> ${LOGFILE} 2>&1  
scp ./patchlist_GI.txt  $HOST:/tmp/.  >> ${LOGFILE} 2>&1  
scp ./set_env.sh $HOST:/tmp/.    >> ${LOGFILE} 2>&1
ssh $HOST "sh $SCRIPTHOME/apply_psu_local_precheck.sh $ORACLE_SID "  >> ${LOGFILE} 2>&1
scp $HOST:/tmp/apply_psu_local_${ORACLE_SID}_precheck.log /tmp/.  >> ${LOGFILE} 2>&1
#check Database PatchVersion, for apply action, if already applied, exits
#if [ $ACTION = "apply1" ] || [ $ACTION = "precheck1" ] 
if [ $ACTION = "apply" ] || [ $ACTION = "precheck" ] 
then
count=`cat /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep ${PATCHVERSION} |wc -l` >> ${LOGFILE} 2>&1
if [ $count = "0" ]
then echo "$ORACLE_SID on $HOST hasn't updated with this patch, -----------PASSED"  |tee -a ${LOGFILE} 
else
echo "$ORACLE_SID on $HOST already updated, do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
fi
fi
#check for how many instance running on OH, if more than 1, exits
OHCOUNT=`cat /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep ORACLE_HOME |cut -d: -f2` >> ${LOGFILE} 2>&1
if [ $OHCOUNT = "1" ]
then
echo "Oracle_Home only has 1 instance:${ORACLE_SID}   -----------PASSED"  |tee -a ${LOGFILE}
else
echo "ORACLE_HOME only has more instances,  do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
fi
#check patchlist in target database are in Gold Image
PL=`cat  /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep PT  |cut -d: -f2` >> ${LOGFILE} 2>&1 
if  [ $PL = "0" ]
then
echo "Patches in database $ORACLE_SID are all included in Golden Image, --------------PASSED"  |tee -a ${LOGFILE}
else
echo "Please compare on $HOST /tmp/patchlist_$ORACLE_SID.txt vs /tmp/patchlist_GI.txt,  do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
fi
}

function get_patchlist_from_GI
{
$SQLDBA  <<EOF
connect / as sysdba
set heading off
SET LINESIZE 500
SET PAGESIZE 0
SET SERVEROUT ON
SET LONG 2000000
spool /tmp/patchlist1_GI.txt
select xmltransform(DBMS_QOPATCH.GET_OPATCH_LIST,dbms_qopatch.get_opatch_xslt) "Patch installed?" from dual;
spool off
EOF

grep "Patch(sqlpatch)"  /tmp/patchlist1_GI.txt > /tmp/patchlist2_GI.txt
cat /tmp/patchlist2_GI.txt |cut -d: -f1 > /tmp/patchlist3_GI.txt
cat /tmp/patchlist3_GI.txt |cut -d ' ' -f2 > /tmp/patchlist_GI.txt

}


function pre_check_HOST
{
#check if the Golden Image exist or not
if [ ! -e $GoldenImageFile ] && [ $ACTION = "apply" ]
then
echo "No Golden Image found, do nothing, ------------Exits" |tee -a  ${LOGFILE}
email_log
exit
else 
echo " Golden Image file found,         -----------PASSED" |tee -a $LOGFILE
fi
#check /orabase size, must be 8G more
 OHSIZE=`ssh $HOST "df -m /orabase |grep orabase " |awk '{print $4}'`   >> ${LOGFILE} 2>&1 
if [[ $OHSIZE = *'%' ]]
then
 OHSIZE=`ssh $HOST "df -m /orabase |grep orabase " |awk '{print $3}'`   >> ${LOGFILE} 2>&1 
fi
if [ $OHSIZE -le  $OHSIZEGI ]
then echo " /orabase size $OHSIZE mb on $HOST is NOT sufficient, do nothing, ------------Exits..." |tee -a  ${LOGFILE} 
email_log
exit
else
 echo " /orabase sze $OHSIZE mb on $HOST is good enought, -----------PASSED" |tee -a $LOGFILE 
fi
#check rman backup dir exist or not
RMANDIR=`cat /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep RMANDIR |cut -d: -f2`
if [ $RMANDIR = "null" ]
then echo "RMANDIR on $HOST is NOT existing, do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
else echo " RMANDIR $RMANDIR on $HOST looks good, able to do rman backup, -----------PASSED" |tee -a $LOGFILE
fi
#check oracle binary group
GROUPNAME=`cat  /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep GROUP  |cut -d: -f2`
if [ $GROUPNAME != "cudba" ]
then echo "Group name on $HOST is NOT cudba, do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
else echo " GROUP NAME $GROUPNAME on $HOST looks good,  -----------PASSED" |tee -a $LOGFILE
fi
##since using rman backup, do not need to check oradata size for cold backup
#ssh $HOST "df -lv  |grep oradata " |awk '{print $5}' > ${LOGFILE}_datasize.txt 2>&1 
#for mountpoint in `cat ${LOGFILE}_datasize.txt`; do 
#DATASIZE2=`echo "${mountpoint%%?}"`
#echo $DATASIZE2 >>  $LOGFILE 2>&1
#if [ "$DATASIZE2" -gt  "$DSF" ]; 
#then echo " one of /oradata ${DATASIZE2}% used space on $HOST, it is more than ${DSF}%, can't do cold backup, do nothing, ------------Exits..." |tee -a ${LOGFILE}
#email_log
#exit
#else
# echo " ${DATASIZE2}% used space on $HOST, it is good enought, able to do cold backup, -----------PASSED" |tee -a $LOGFILE
#fi
#done
#check Oracle Home path, if not match, ------------Exits
#apply_psu_local_${ORACLE_SID}_precheck.log is generated by apply_psu_local_precheck.sh in local
OHPATH=`cat /tmp/apply_psu_local_${ORACLE_SID}_precheck.log |grep OHPATH |cut -d: -f2`
if [ $OHPATH != $OHPATHGI ]
then echo " Oracle Home $OHPATH on $HOST is NOT sames as it supposed to be, do nothing, ------------Exits..." |tee -a ${LOGFILE}
email_log
exit
else echo " Oracle Home $OHPATH path on $HOST matched Golden Image, -----------PASSED" |tee -a $LOGFILE 
fi
}

function email_log
{
if [ -e  ${LOGFILE}_exit.log ]
then
mv   ${LOGFILE}_exit.log  ${LOGFILE}_exit.log_bk  
fi
cat $LOGFILE |grep  -i Exits > ${LOGFILE}_exit.log 
if [ -e  ${LOGFILE}_exit.log ]
then
echo "sending email for abort action" 
/bin/mail -s 'Oracle PSU patch applying does not proceed... ' $MAILINGLIST < ${LOGFILE}_exit.log 
else echo "not sending email"
fi
}


function action_on_patch 
{
if [ -e /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log ]
then
mv /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log-OLD
fi
if [ -e  /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log_verify ]
then
mv  /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log_verify  /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log_verify-bk
fi
scp ./set_env.sh $HOST:/tmp/.    >>  ${LOGFILE} 2>&1
scp ./apply_psu_local_${ACTION}.sh $HOST:$SCRIPTHOME/.   >>  ${LOGFILE} 2>&1
ssh $HOST "nohup bash $SCRIPTHOME/apply_psu_local_${ACTION}.sh $ORACLE_SID &"  >>  ${LOGFILE} 2>&1 
scp $HOST:/tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log /tmp/. >>  ${LOGFILE} 2>&1
scp $HOST:/tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log_verify /tmp/. >>  ${LOGFILE} 2>&1
scp $HOST:/tmp/patchlist_${ORACLE_SID}.txt /tmp/. >>  ${LOGFILE} 2>&1
/bin/mail -s "$ACTION $ORACLE_SID PSU Status ... " $MAILINGLIST < /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log
/bin/mail -s "Verifying $ORACLE_SID on $host PSU patch Status ... " $MAILINGLIST < /tmp/apply_psu_local_${ORACLE_SID}_${ACTION}.log_verify 
echo "End of applying."  |tee -a $LOGFILE
}


#main
 
if test $# -ne 4 
  then
   f_usage
    return 1
 fi

 if [ $ACTION != "precheck" ] && [ $ACTION != "apply" ] && [ $ACTION != "rollback" ]
 then
   echo $ACTION
  f_usage
   return 1
  fi

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQLDBA

 LOGFILE=/tmp/apply_psu_q4_2017_${ORACLE_SID}_${ACTION}.log
 echo $NOW > $LOGFILE 

 pre_check_OH   
 pre_check_HOST   
 action_on_patch >> $LOGFILE  2>&1
 echo "---end of this---"  |tee -a $LOGFILE 
 echo $NOW >> $LOGFILE


exit

