create or replace view rman.vw_rman_last_cold_status
as 
with f as
(
select a.name,a.dbid,to_char(max(b.completion_time),'YYYY-MM-DD hh24:mi:ss') LAST_COLD_BACKUP
 from rc_database a,bs b, RC_DATABASE_INCARNATION c
 where a.db_key=b.db_key
 and b.bs_key not in(Select bs_key from rc_backup_controlfile where AUTOBACKUP_DATE
 is not null or AUTOBACKUP_SEQUENCE is not null)
 and b.bs_key not in(select bs_key from rc_backup_spfile)
 and b.completion_time > sysdate - 100
and b.BCK_TYPE = 'D'  
and b.INCR_LEVEL is null 
and a.dbid = c.dbid
and c.status = 'CURRENT'
and not exists (select 1 from bs c where b.db_key = c.db_key and  c.BCK_TYPE = 'I' and c.INCR_LEVEL='0' and c.completion_time > sysdate - 30  )
group by  a.name,a.dbid
) 
select f.name,f.LAST_COLD_BACKUP LAST_COLD_BACKUP
from f 
order by 1,2 
/
