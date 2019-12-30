#!/bin/bash

function get_patchlist_from_GI
{
mv /tmp/patchlist_GI.txt /tmp/patchlist_GI.txt-bk
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

function copy_over
{
cp /tmp/patchlist_GI.txt ~/bin/.
cp /tmp/patchlist_GI.txt ~/bin/test/.
}

#main

. set_env.sh patch1t
SQLDBA="$ORACLE_HOME/bin/sqlplus -s / as sysdba "
export SQL_DBA

get_patchlist_from_GI
copy_over

