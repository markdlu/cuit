#!/bin/bash
#history Mark Lu 11/24/2019 initlized
# info: this script will restore the db to db_restore;
#       the /tmp/restore.info file contains path of full and/or incremental backup  
#       there is a schema_only.sql in full backupdir in case there is no 
#       object exists in orignal db          
#  Mark Lu -- modified for above fuction 12/27/2019
#          -- add restore a whole db 01/07/2020 
#          -- modify restore db name with _$now 
#          -- modify using a temp backup dir in order to restore more than once
#
###############################################################

function set_env
{
export username=`cat $HOME/.pw |grep username |cut -d: -f2 `
echo "username: "  $username
export password=`cat $HOME/.pw |grep password |cut -d: -f2 `
export targetdir=`cat /tmp/restore.info |grep ^fullbackupdir |cut -d':' -f2 `
sudo rm -rf ${targetdir}_current
sudo cp -rp ${targetdir} ${targetdir}_current 
sudo chmod -R 777 ${targetdir}_current
export targetdir=${targetdir}_current
sudo /usr/bin/xtrabackup --decompress --target-dir=${targetdir}
export incrementaldir=`cat /tmp/restore.info |grep ^incbackupdir |cut -d':' -f2`
if [ "$incrementaldir" != "null" ]
then
sudo rm -rf ${incrementaldir}_current
sudo cp -rp ${incrementaldir} ${incrementaldir}_current
sudo chmod -R 777  ${incrementaldir}_current
export incrementaldir=${incrementaldir}_current
sudo /usr/bin/xtrabackup --decompress --target-dir=${incrementaldir}
fi 
echo "targetdir is:"  "$targetdir"
echo "incrementaldir is: " "$incrementaldir"
now=`date +%Y%d%H%M%S`
#mysql -u${username} -p${password} -e "set global wsrep_on=OFF ;"
}

function restore_db
{
mysql -u${username} -p${password} -e "use ${dbname} ; show tables ;" > table_all.txt 
cat table_all.txt |grep -v Tables_in > table_all_2.txt
cp table_all_2.txt table_all.txt

#prepare full datadir first
sudo /usr/bin/xtrabackup --prepare --apply-log-only --target-dir=${targetdir}

#then prepare incremental dir
if [ "$incrementaldir" == "null" ]
then
echo "no incremental backup yet"
else
echo "apply incremental to full..."
echo "targetdir is:"  "$targetdir"
echo "incrementaldir is: " "$incrementaldir"
sudo /usr/bin/xtrabackup --prepare --apply-log-only --target-dir=${targetdir} --incremental-dir=${incrementaldir}
if [ $? != 0 ]
then
echo "incremental prepare failed.."
exit 1
fi
fi


#finally copy back from full datadir --restore
mysql -u${username} -p${password} -e "drop database if exists ${dbname}_$now ;" 
for i in `cat table_all.txt`
do
export tbname=$i
echo "table name is : " $tbname
create_object;
done

echo "copy table to new database ${dbname}_$now dir..."
sudo cp -rp $targetdir/$dbname/* /data/mysql/data/${dbname}_$now/.
sudo chown -R mysql:mysql /data/mysql/data/${dbname}_$now/

for i in `cat table_all.txt`
do
export tbname=$i
mysql -u${username} -p${password} -e "ALTER TABLE ${dbname}_$now.$i IMPORT TABLESPACE;"
mysql -u${username} -p${password} -e "use ${dbname}_$now;select * from $i limit 3 ;"
done

echo "restore db is done"

}


function restore_table
{
#prepare full datadir first
sudo /usr/bin/xtrabackup --prepare --apply-log-only --target-dir=${targetdir}

#then prepare incremental dir
if [ "$incrementaldir" == "null" ]
then
echo "no incremental backup yet"
else
echo "apply incremental to full..."
echo "targetdir is:"  "$targetdir"
echo "incrementaldir is: " "$incrementaldir"
sudo /usr/bin/xtrabackup --prepare --apply-log-only --target-dir=${targetdir} --incremental-dir=${incrementaldir}
if [ $? != 0 ]
then 
echo "incremental prepare failed.."
exit 1
fi
fi

#finally copy back from full datadir --restore
create_object;
echo "copy signgle table $tbname to new database ${dbname}_$now dir..."
sudo cp -rp $targetdir/$dbname/$tbname.* /data/mysql/data/${dbname}_$now/.
sudo chown -R mysql:mysql /data/mysql/data/${dbname}_$now/
mysql -u${username} -p${password} -e "ALTER TABLE ${dbname}_$now.$tbname IMPORT TABLESPACE;"
mysql -u${username} -p${password} -e "use ${dbname}_$now;select * from $tbname limit 3 ;"
echo "restore table is done"
}

function usage
{
echo "usage: "
echo "$0 db dbname " 
echo "or"
echo "$0 table dbname tablename " 
exit 1
}

function create_object
{
echo "running create object function..."
mysql -u${username} -p${password} -e "create database if not exists ${dbname}_$now ;" 
mysql -u${username} -p${password} -e "use ${dbname}_$now; drop table if exists ${tbname} ;" 
mysql -u${username} -p${password} -e "use $dbname;show create table ${tbname};" > create_tb.tmp
echo "use ${dbname}_$now;" > creat_tb.sql
tail -1 create_tb.tmp  | awk '{$1= ""; print $0}' >> creat_tb.sql 
fkflag=`cat creat_tb.sql |grep "FOREIGN KEY" |wc -l` 
if [ "$fkflag" == "1" ]
then
fk=`cat creat_tb.sql | grep -o -P '(?<=CONSTRAINT).*(?=FOREIGN)'`
echo ";alter table ${dbname}_$now.${tbname} drop FOREIGN KEY $fk;" >> creat_tb.sql 
echo "ALTER TABLE ${dbname}_$now.${tbname} DISCARD TABLESPACE; " >> creat_tb.sql
else
echo ";ALTER TABLE ${dbname}_$now.${tbname} DISCARD TABLESPACE; " >> creat_tb.sql
fi
mysql -u${username} -p${password} < creat_tb.sql > create_tb.out 2>&1
err=`cat create_tb.out |grep error |wc -l`
if [ "$err" != "0" ]
then
echo "table created failed, need to check..."
cat create_tb.out
exit 1
else 
echo "table $dbanme created in ${dbname}_$now"
fi
}

#main

restore_mode=$1
dbname=$2
tbname=$3

echo $#
if [ "$#" -lt "2" ] 
then
echo "wrong arguments"
usage;
fi

set_env;

if [ "${restore_mode}" == "db" ]
then
echo "restore db $dbname"
restore_db
elif  [ "${restore_mode}" == "table" ]
then
echo "restore table $tbname"
restore_table
else
echo "Wrong restore_mode"
usage;
fi
