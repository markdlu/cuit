#!/bin/bash
#       Name
###########################################################

export V_PASSWD=`grep "rman1t:rman" ~/.getpw.lst|cut -f 3 -d ':'`

. ${HOME}/set_env.sh patch1t 
day=`date +%d`

function rman_catalog_un_re_regiseter
{
#get orphan dbid
$ORACLE_HOME/bin/rman <<EOF
connect target /
connect catalog rman/${V_PASSWD}@rman1t
spool log to /tmp/dbid.log
list incarnation of database;
spool log off;
EOF

egrep -i -v "Spooling|Recovery|RMAN|List|DB|-----" /tmp/dbid.log | awk '{print $4}' | sed '/^$/d' |sort |uniq > /tmp/dbid2.log

#clean old orphan dbid from catalog
echo "unreigster dbid"
for x in `cat /tmp/dbid2.log`
do
$ORACLE_HOME/bin/rman <<EOF
connect catalog rman/${V_PASSWD}@rman1t
set DBID $x;
UNREGISTER DATABASE NOPROMPT;
EOF
echo "M1"
done

mv /tmp/dbid.log /tmp/dbid.log-OLD
mv /tmp/dbid2.log /tmp/dbid2.log-OLD

#register dbid after clone
echo "re-register dbid"
$ORACLE_HOME/bin/rman <<EOF
connect target /
connect catalog rman/${V_PASSWD}@rman1t
register database;
EOF

}

#main

rman_catalog_un_re_regiseter;




