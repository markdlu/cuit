#!/bin/bash
#---------------------------------------------------------------------------------------------------
# Program:      list_rman_backup_status.sh
#
# Purpose:      To apply quarterly PSU patch automatically
#
# Author:       Mark Lu
# Date:         02/21/2018
# Version:      1.1
#################################################################################################

. ~/.bash_profile
. ~/set_env.sh patch1t 

export V_PASSWD=`grep "rman1p:rman" ~/.getpw.lst|cut -f 3 -d ':'`

DOY=`date +%m%d%Y`
TOD=`date +%H%M%S`
NOW=`date +%m"/"%d"/"%Y" "%H":"%M":"%S`

catalog=rman1p
MAILTO='oradmin@columbia.edu,spersaud@columbia.edu'
#MAILTO='ml4147@columbia.edu'

list_backup()
{
$SQLDBA <<EOF > /tmp/list_rman_exception_${catalog}_log
connect rman/${V_PASSWD}@$catalog
set linesize 200
set heading off
select 'PROD Full backup NOT within 1 week or Increnmetal NOT within 48 hours:' from dual;
set heading on 
select * from rman.vw_rman_last_status
where 
 name like '%P'
and (LAST_FULL_BACKUP < sysdate - 8 or (LAST_INCREMENTAL_BACKUP < sysdate - 2 and LAST_FULL_BACKUP < LAST_INCREMENTAL_BACKUP ))
order by 2, 3 desc;

set heading off
select 'Non-PROD Full backup NOT within 1 week or Increnmetal NOT within 48 hours:' from dual;
set heading on 
select * from rman.vw_rman_last_status
where 
name not like '%P'
and name not in ( select name from rman.vw_rman_last_cold_status)
and (LAST_FULL_BACKUP < sysdate - 8 or (LAST_INCREMENTAL_BACKUP < sysdate - 2 and LAST_FULL_BACKUP < LAST_INCREMENTAL_BACKUP  ))
union 
select * from rman.vw_rman_last_status@rman1tlink
where name ='RMAN1P'
and (LAST_FULL_BACKUP < sysdate - 8 or (LAST_INCREMENTAL_BACKUP < sysdate - 2 and LAST_FULL_BACKUP < LAST_INCREMENTAL_BACKUP ))
order by 2, 3 desc;
EOF

$SQLDBA <<EOF >> /tmp/list_rman_exception_${catalog}_log
connect rman/${V_PASSWD}@$catalog
set linesize 200
set heading off
select 'Full Cold backup NOT within 1 week :' from dual;
set heading on
select * from rman.vw_rman_last_cold_status
where
LAST_COLD_BACKUP < sysdate - 8 
order by 2,1 desc;
EOF


$SQLDBA <<EOF  >>  /tmp/list_rman_exception_${catalog}_log
connect rman/${V_PASSWD}@$catalog
set linesize 200
set heading off
select 'ALL Last Full/Incremental backup:' from dual;
set heading on 
select name, LAST_FULL_BACKUP, LAST_INCREMENTAL_BACKUP from rman.vw_rman_last_status
where  name not in (select name from rman.vw_rman_last_cold_status)
union
select name, LAST_FULL_BACKUP, LAST_INCREMENTAL_BACKUP from rman.vw_rman_last_status@rman1tlink
where name ='RMAN1P'
;
set heading off
select 'ALL Last Full Cold backup :' from dual;
set heading on
select name,LAST_COLD_BACKUP from rman.vw_rman_last_cold_status
order by 2, 1 desc;
EOF
}


get_backup_to_csv()
{
$SQLDBA <<EOF  
connect rman/${V_PASSWD}@$catalog
set colsep ,     
set pagesize 0   
set trimspool on 
set headsep on
set linesize 300   
set heading on
col name for a20
col host_name for a50
col LAST_FULL_BACKUP for a30
col LAST_FULL_BACKUP_DATE for a30
spool /hmt/eos-nfs-3/patching/output/history/OracleBackupLogs/Oracle_Backup_Log.csv 
select 'host_name' as host_name, 'name' as name, 'LAST_FULL_BACKUP_DATE' as LAST_FULL_BACKUP_DATE, 'LAST_INCREMENTAL_BACKUP_DATE' as LAST_INCREMENTAL_BACKUP_DATE from dual;
with b as
(
select host_name, regexp_substr(UPPER(target_name),'[^.]+',1,1) as name from sysman.mgmt_targets@emrep1plink where TARGET_TYPE ='oracle_database'
)
select b.host_name host_name,a.name name, a.LAST_FULL_BACKUP LAST_FULL_BACKUP, a.LAST_INCREMENTAL_BACKUP LAST_INCREMENTAL_BACKUP from rman.vw_rman_last_status a, b
where  a.name not in (select name from rman.vw_rman_last_cold_status)
and a.name = b.name
union
select b.host_name host_name, a.name name, a.LAST_FULL_BACKUP LAST_FULL_BACKUP, a.LAST_INCREMENTAL_BACKUP LAST_INCREMENTAL_BACKUP from rman.vw_rman_last_status@rman1tlink a, b
where a.name ='RMAN1P'
and a.name = b.name;
spool off
EOF
}

list_db_notincatalog()
{
$SQLDBA <<EOF  >>  /tmp/list_rman_exception_${catalog}_log
connect rman/${V_PASSWD}@$catalog
set linesize 200
set heading off
select 'Databases are NOT registed in rman catalog:' from dual;
with a as
(
select regexp_substr(UPPER(target_name),'[^.]+',1,1) as name from sysman.mgmt\$target_properties@emrep1plink where PROPERTY_NAME ='DBVersion' and PROPERTY_VALUE ='12.1.0.2.0'
)
select a.name from a 
where
 name not in (
 select name from rman.rc_database
)
and 
name not in ('RMAN1P','FDSPRD2','FDSPRD2_NEW','FN92PRE','FN92RPT','HR92PRE','HR92RPT','SKRPT1P','SKRPT1D')
order by name;
EOF
}

email_output()
{
 mailx -s "RMAN1P Daily Backup Report " $MAILTO < /tmp/list_rman_exception_${catalog}_log 
 mv /tmp/list_rman_exception_${catalog}_log /tmp/list_rman_exception_${catalog}_log-OLD 
}

#main

SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "

list_backup
list_db_notincatalog
email_output
get_backup_to_csv;
