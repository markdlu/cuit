set colsep ,
-- set lines 2500 pages 0 trimspool on 
set linesize 2500
set pagesize 300
set feedback off echo off
set und off
alter session set nls_date_format='MM/DD/YYYY HH24:MI:ss ';
column HOST_NAME heading 'Host Name' justify left format a40 truncated
column DATABASE_NAME heading 'Database Name' justify left format a40 truncated
column DATABASE_PURPOSE heading 'Databse Purpose' justify left format a40 truncated
column DATABASE_VERSION heading 'Database Version' justify left format a40 truncated
column ORACLE_HOME heading 'Oracle Home' justify left format a60 truncated
column PATCH_ID heading 'Patch ID' justify left format a40 truncated
column PATCH_TYPE heading 'Patch Type' justify left format a40 truncated 
column RELEASE_QUARTER heading 'Release Quarter' justify left format a40 truncated
column BEHIND_MONTHS heading 'Behind Months' justify right format 999

--spool test.txt
spool ${script_dir}/output/database/opatch_status_report_${DATETIME}.csv
select CAPTURE_DATE,
    OEM_COLLECTION_DATE,
    HOST_NAME,
    DATABASE_NAME,
    DATABASE_PURPOSE,
    DATABASE_VERSION,
    ORACLE_HOME,
    PATCH_ID,
    PATCH_TYPE,
    RELEASE_QUARTER,
    INSTALL_DATE,
    BEHIND_MONTHS
 from dbinfo.oracle_db_patch_info_v@dbtrac1p;
spool off

