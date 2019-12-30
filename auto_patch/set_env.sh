#!/bin/ksh
#
case $# in
0)
        ;;
1)
                ANSWER=$1
                ORACLE_SID=`grep "^${ANSWER}:" /etc/oratab|cut -d: -f1 -s`
                ORACLE_HOME=`grep "^${ANSWER}:" /etc/oratab|cut -d: -f2 -s`
                #if [ "${ORACLE_SID}" = "" ]
                #then
                #        # Set to first entry in oratab
                #        ORACLE_SID=`cat /etc/oratab|grep -v "^#"|cut -d: -f1 -s|head -1`
                #        ORACLE_HOME=`cat /etc/oratab|grep -v "^#"|cut -d: -f2 -s|head -1`
                #fi

                ORAENV_ASK=NO
                . ${ORACLE_HOME}/bin/oraenv 1>/dev/null
                ORAENV_ASK=
                #echo Oracle SID is now `tput rev`$ORACLE_SID`tput rmso`, Oracle Home is `tput rev`$ORACLE_HOME`tput rmso`
        ;;
*)
        ;;

esac

set -o vi
EDITOR=vi
#PS1=`uname -n `':($ORACLE_SID) $ '
PATH=/usr/bin:/bin:/usr/opt/bin:/opt/bin:/opt/freeware/bin:/etc/init.d:/usr/sbin:/sbin:/usr/opt/sbin:/opt/sbin:/opt/freeware/sbin:/etc:/usr/ucb:/usr/bin/X11:/usr/sybase/bin:/usr/java14/jre/bin:/usr/java14/bin:.
export PATH
export ORACLE_BASE=/usr/oracle
export ORACLE_SID
export ORACLE_HOME
export TNS_ADMIN=$ORACLE_HOME/network/admin/$ORACLE_SID
export LIBPATH=$ORACLE_HOME/lib:$LIBPATH
export DBA_BIN=/oradmin/common/scripts
export DBA_LOG=/oradmin/commong/logs
export DBA_DB_LOG=/oradmin/${ORACLE_SID}/logs
PATH=${ORACLE_HOME}/bin:${DBA_BIN}:${PATH}
export PATH
export hn=`hostname -s`
export oh=${ORACLE_HOME}
export PS1=$'${hn}"("${ORACLE_SID}"|"${oh})":"${PWD}"\n-> '

