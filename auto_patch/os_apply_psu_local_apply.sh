#!/bin/bash
#
#  this is local apply script been called by master scripts to apply PSU patch quartly  
#  this is assuming each databae instance on each host only
#
#  V1 -- Mark Lu initialized on Oct 22, 2018 
#
#  Modified By    Time         Reason
#  Mark Lu       10/22/2018    this is local psu apply patch for OS patch to inilizing.  
#
#####################################################
if [ -e  ~/.bash_profile ]
then
. ~/.bash_profile
fi 

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`
PNAME=${0##*/}


ACTION=$1
EMAIL=$2

function get_parameter
{
LOCALAPPLYFLAG=`cat /etc/oratab |grep ^PSU |grep -v grep |cut -d: -f2`
GLOBALAPPLYFLAG=`grep ^GLOBALAPPLY  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2` 
echo "M0: " $GLOBALAPPLYFLAG
PATCHNUMBER=`grep ^PATCHNUMBER  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2`
OHSIZEGI=`grep ^OHSIZEGI /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2`
GROUP=`grep ^GROUP /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2`
}

function get_email
{
if [ -z "$EMAIL" ]
then
echo "no s2"
MAILINGLIST=`grep ^MAILINGLIST /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
PREMAILINGLIST=`grep ^PREMAILINGLIST /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
PAGER=`grep ^PAGER /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
else
echo "yes s2"
MAILINGLIST="$EMAIL"@columbia.edu
PREMAILINGLIST="$EMAIL"@columbia.edu
PAGER="$EMAIL"@columbia.edu
fi
HOST=`uname -n`
}



function get_parameter2
{
LOCALAPPLYFLAG=`cat /etc/oratab |grep ^PSU |grep -v grep |cut -d: -f2`
GLOBALAPPLYFLAG=`grep ^GLOBALAPPLY  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
PATCHNUMBER=`grep ^PATCHNUMBER  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
OHSIZEGI=`grep ^OHSIZEGI /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
GROUP=`grep ^GROUP /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
}

function set_env
{
PMON_NUM=`ps -ef |grep pmon |grep -v grep |wc -l`
if [ $PMON_NUM = 1 ]
then
echo "there is only 1 instance running, ------PASSED..." |tee -a  ${EVNLOGFILE}
else
echo "there is no instarnce or more instances running, ------Exits..." |tee -a  ${EVNLOGFILE}
email_log
exit 2
fi

 #set Oracle Enviroment
 unset ORACLE_PATH
 unset SQLPATH
 unset ORACLE_HOME
 export ORACLE_SID=`ps -ef |grep pmon |grep -v grep | awk '{print $8}'  |cut -d_ -f3`
 export ORACLE_HOME=`cat /etc/oratab |grep ^$ORACLE_SID |grep Y |cut -d: -f2`
 export LD_LIBRARY_PATH=$ORACLE_HOME/lib
 export TNS_ADMIN=$ORACLE_HOME/network/admin/${ORACLE_SID}
 export LIBPATH=$ORACLE_HOME/lib:$LIBPATH
 export PATH=${ORACLE_HOME}/bin:${DBA_BIN}:${PATH}:${ORACLE_HOME}/OPatch


  if [ $ORACLE_HOME = "/orabase/product/12.1.0.2" ]
  then GoldenImageFile=`grep ^12.1.0.2  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2` 
  elif [ $ORACLE_HOME = "/orabase/product/12.1.0/2.0" ]
  then GoldenImageFile=`grep ^2.0 /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU.cnf |cut -d: -f2` 
  elif [ $ORACLE_HOME = "/orabase/product/12.2.0.1" ]
  then GoldenImageFile=`grep ^12.2.0.1  /kickstart/local_packages/oracle/Linux/x86-64/PSU/PSU_122.cnf |cut -d: -f2`
  else echo "Oracle Home is neither 12.1.0.2 nor 12.1.0/2.0 nor 12.2.0.1, -------------------Exits  " >> ${EVNLOGFILE}
  email_log
  exit 2
  fi
}


function pre_check_HOST
{
if [ -z "$GLOBALAPPLYFLAG" ]
then GLOBALAPPLYFLAG="N"
fi
if [ $GLOBALAPPLYFLAG != 'Y' ]
then
echo "M1: global flag: " $GLOBALAPPLYFLAG 
echo "Global Flag is Not Y, skipping.., --------------Exits"  |tee -a  ${PRELOGFILE}
email_log
exit 2 
else  echo "Global Flag is Y, --------------PASSED"  |tee -a  ${PRELOGFILE}
fi

if [ -z "$LOCALAPPLYFLAG" ]
then LOCALAPPLYFLAG="N"
fi
if [ $LOCALAPPLYFLAG != 'Y' ]
then
echo "Local Flag is Not Y, skipping.., --------------Exits"  |tee -a  ${PRELOGFILE}
email_log
exit 2
else  echo "Local Flag is Y, --------------PASSED"  |tee -a  ${PRELOGFILE}
fi

#check if the Golden Image exist or not
if [ ! -e $GoldenImageFile ] 
then
echo "No Golden Image found, do nothing, ------------Exits" |tee -a  ${PRELOGFILE}
email_log
exit 2
else
echo " Golden Image file found,         -----------PASSED" |tee -a $PRELOGFILE
fi
#check /orabase size, must be 8G more
 OHSIZE=`df -m /orabase |tail -1  |awk '{print $4}'`   >> ${PRELOGFILE} 2>&1
if [ "$OHSIZE" = "*'%'" ]
then
 OHSIZE=`df -m /orabase |tail -1 |awk  '{print $3}'`   >> ${PRELOGFILE} 2>&1
fi
echo "OHSIZE"  "$OHSIZE"
if [ "$OHSIZE"  -le  "$OHSIZEGI" ]
then echo " /orabase size $OHSIZE mb on $HOST is NOT sufficient, do nothing, ------------Exits..." |tee -a  ${PRELOGFILE}
email_log
exit 2
else
 echo " /orabase sze $OHSIZE mb on $HOST is good enought, -----------PASSED" |tee -a $PRELOGFILE
fi

#check oracle instance is up nor not
PMON_NUM=`ps -ef |grep pmon |grep -v grep |wc -l`
if [ $PMON_NUM = 1 ]
then
echo "there is only 1 instance running, ------PASSED..." |tee -a  ${EVNLOGFILE}
else
echo "there is no instarnce or more instances running, ------Exits..." |tee -a  ${EVNLOGFILE}
email_log
exit 2
fi

#check oracle group name
gflag=`id |grep $GROUP |wc -l `
if [ $gflag -eq 1 ]
then
echo "GROUP:cudba" >> ${PRELOGFILE} 2>&1
echo " GROUP NAME cudba  on $HOST looks good,  -----------PASSED" |tee -a $PRELOGFILE
else
echo "GROUP:bad" >> ${LOGFILE} 2>&1
echo "Group name on $HOST is NOT cudba, do nothing, ------------Exits..." |tee -a ${PRELOGFILE}
email_log
exit 2
fi


#check if patch is already applied or not
PATCHAPPLIED_FLAG=`$ORACLE_HOME/OPatch/opatch lsinventory |grep $PATCHNUMBER  |grep applied  |grep -v grep |wc -l`
if [ $PATCHAPPLIED_FLAG = 1 ]
then
echo "Patch $PATCHNUMBER already applied, skipping.., --------------Exits"  |tee -a  ${PRELOGFILE}  
#email_log
exit 2
else echo "Patch $PATCHNUMBER has not applied, --------------PASSED"  |tee -a  ${PRELOGFILE}
fi

#if all passed, still send notification out
#/bin/mail -s "$HOST PSU precheck Status ... " $MAILINGLIST < ${PRELOGFILE} 
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
echo "M1"  >> $LOGFILE 2>&1
$SQLDBA  <<EOF  >> $LOGFILE 2>&1
set heading off
shutdown abort;
startup;
shutdown immediate;
quit
EOF
date >> $LOGFILE 
}

function start_db 
{
date >> $LOGFILE 
$SQLDBA  <<EOF  >> $LOGFILE 2>&1 
set heading off
startup;
quit
EOF
date >> $LOGFILE 
}

function run_sql 
{
echo "OH"  $ORACLE_HOME
echo "SID"  $ORACLE_SID
DATABASE_ROLE=`$SQLDBA  <<EOF
set heading off
SET LINESIZE 500
SET PAGESIZE 1000
SET ESCAPE ON
SET SERVEROUT ON
select database_role from v\\$database;
exit
EOF`
echo "Role:" $DATABASE_ROLE >> $LOGFILE 2>&1


if [ $DATABASE_ROLE = "PRIMARY" ]
then
echo "  "   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "Apply SQL on $ORACLE_SID starting..."   >> $LOGFILE 2>&1
sh $ORACLE_HOME/OPatch/datapatch -verbose   >> $LOGFILE 2>&1 
echo "Apply SQL on $ORACLE_SID Ended..."   >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "  "   >> $LOGFILE 2>&1
elif [ $DATABASE_ROLE = "PHYSICAL STANDBY" ]
then "The database is Standby, no sql applied..."   >> $LOGFILE 2>&1
else echo "Database is not pimary, do not run sql..." >> $LOGFILE 2>&1
fi

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
sleep 2
#/bin/mail -s "$ACTION $ORACLE_SID PSU Status ... " $MAILINGLIST < ${LOGFILE} 
#/bin/mail -s "Verifying $ORACLE_SID on $host PSU patch Status ... " $MAILINGLIST < ${LOGFILE}_verify 
}

function verify_db
{
echo "Verify DB Starting..."   >> $LOGFILE 2>&1
mode=`$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba
set heading off
set escape '\'
set feedback off
set serveroutput off
select * from dual; 
EOF`
string=`echo $mode`
echo "$string"   >> $LOGFILE 2>&1
echo "Verify DB ended..."   >> $LOGFILE 2>&1
if [ "$string" = "X" ]
then
/bin/mail -s "$ACTION $ORACLE_SID PSU Status ... " $MAILINGLIST < ${LOGFILE} 
/bin/mail -s "Verifying $ORACLE_SID on $host PSU patch Status ... " $MAILINGLIST < ${LOGFILE}_verify 
exit 0;
else
/bin/mail -s "$ACTION $ORACLE_SID PSU Status ... " $MAILINGLIST < ${LOGFILE} 
/bin/mail -s "$ORACLE_SID on `uname -n` is not up,please check ASAP!... "  $PAGER
exit 1;
fi
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
if  [ ! -d $ORACLE_HOME/network/admin/$ORACLE_SID ]
then
TNS_ADMIN=$ORACLE_HOME/network/admin
else
TNS_ADMIN=$ORACLE_HOME/network/admin/$lsn
fi
if [ ! -d $ORACLE_HOME/network/admin/$lsn ]
then
ln -s $ORACLE_HOME/network/admin/$ORACLE_SID $ORACLE_HOME/network/admin/$lsn
fi
echo ${lsn}                              >> $LOGFILE   2>&1
$ORACLE_HOME/bin/lsnrctl reload ${lsn}    >> $LOGFILE  2>&1
#$ORACLE_HOME/bin/lsnrctl start ${lsn}   >> $LOGFILE  2>&1
#sleep 500
$ORACLE_HOME/bin/lsnrctl status ${lsn}  >>  $LOGFILE 2>&1
echo "Restart listener Ended... "   >> $LOGFILE 2>&1
date >> $LOGFILE
}


function begin_blackout
{
echo "  "    >> $LOGFILE 2>&1
date >> $LOGFILE 
echo "beging blackout on node leve on $host "   >> $LOGFILE 2>&1
OEMPATH=`cat /etc/oratab |grep agent13 |grep -v '#'  |cut -d: -f2`  >> $LOGFILE 2>&1
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
OEMPATH=`cat /etc/oratab |grep agent13  |grep -v '#' |cut -d: -f2`  >> $LOGFILE 2>&1
$OEMPATH/bin/emctl stop blackout myblackout >> $LOGFILE 2>&1 
sleep 10
$OEMPATH/bin/emctl status blackout >> $LOGFILE 2>&1 
date >> $LOGFILE 
}


function email_log
{
if [ -e  ${PRELOGFILE}_exit.log ]
then
mv   ${PRELOGFILE}_exit.log  ${PRELOGFILE}_exit.log.bk
fi
cat $EVNLOGFILE |grep  -i Exits > ${PRELOGFILE}_exit.log
cat $PRELOGFILE |grep  -i Exits >>  ${PRELOGFILE}_exit.log
if [ -e  ${PRELOGFILE}_exit.log ]
then
echo "sending email for abort action"
/bin/mail -s "$HOST Oracle PSU patch applying does not proceed... " $PREMAILINGLIST < ${PRELOGFILE}_exit.log
else echo "not sending email"
fi
}


function f_usage
{
#this function will display the usage requirements for the script
    printf "

 PARAM 1 - Action  

 Usage: $PNAME  [ precheck | apply ] [ optional UNI ]
    "
    exit 1
}


#main


if test $# -eq 0 
  then
   f_usage
    return 1
 fi

 if [ $ACTION != "precheck" ] && [ $ACTION != "apply" ] 
 then
   echo $ACTION
  f_usage
   return 1
  fi


EVNLOGFILE=/tmp/apply_psu_local_env.log
PRELOGFILE=/tmp/apply_psu_local_${HOST}_precheck.log
LOGFILE=/tmp/apply_psu_local_${HOST}_apply.log
cat /dev/null > $EVNLOGFILE
cat /dev/null > $PRELOGFILE
cat /dev/null > $LOGFILE

get_email;
set_env;
ora_verion=`echo ${ORACLE_HOME} |awk -F '/' '{print $4}'`
echo ${ora_verion}
if [ "${ora_verion}" == "12.1.0.2" ] || [ "${ora_verion}" == "12.1.0" ]
then 
get_parameter;
elif [ "${ora_verion}" == "12.2.0.1" ]
then
get_parameter2;
fi 

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQL_DBA

echo "${ORACLE_SID}" > $LOGFILE
echo "${ORACLE_HOME}" >> $LOGFILE


if [ $ACTION = "precheck" ]
then
pre_check_HOST;
elif [ $ACTION = "apply" ]
then

pre_check_HOST;
begin_blackout;
sleep 20;
stop_db;
apply_patch;
start_db;
run_sql
restart_listener;
sleep 10
end_blackout;
verify_version;
verify_db;
else f_usage;
fi
