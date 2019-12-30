create or replace view rman.vw_rman_last_status
as 
with f as
(
select a.name,a.dbid,to_char(max(b.completion_time),'YYYY-MM-DD hh24:mi:ss') LAST_FULL_BACKUP
 from rc_database a,bs b, RC_DATABASE_INCARNATION c
 where a.db_key=b.db_key
and b.bck_type is not null
 and b.bs_key not in(Select bs_key from rc_backup_controlfile where AUTOBACKUP_DATE
 is not null or AUTOBACKUP_SEQUENCE is not null)
 and b.bs_key not in(select bs_key from rc_backup_spfile)
 and b.completion_time > sysdate - 100
and b.INCR_LEVEL = 0  
and a.dbid = c.dbid
and c.status = 'CURRENT'
group by  a.name,a.dbid
) ,
i as
(select a.name ,a.dbid,to_char(max(b.completion_time),'YYYY-MM-DD hh24:mi:ss') LAST_INCREMENTAL_BACKUP
 from rc_database a,bs b, RC_DATABASE_INCARNATION c
 where a.db_key=b.db_key
and b.bck_type is not null
 and b.bs_key not in(Select bs_key from rc_backup_controlfile where AUTOBACKUP_DATE
 is not null or AUTOBACKUP_SEQUENCE is not null)
 and b.bs_key not in(select bs_key from rc_backup_spfile)
 and b.completion_time > sysdate - 100
and b.INCR_LEVEL =  1
and a.dbid = c.dbid
and c.status = 'CURRENT'
group by  a.name,a.dbid
)
select f.name,f.LAST_FULL_BACKUP LAST_FULL_BACKUP, i.LAST_INCREMENTAL_BACKUP LAST_INCREMENTAL_BACKUP
from f left join i on f.name = i.name
order by 2,3
/
