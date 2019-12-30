#!/usr/bin/sh
. ~/set_env.sh $1 
$ORACLE_HOME/bin/rman target / rcvcat rman/rman@rman1t  CMDFILE restore_archive.rman  msglog restore.log

