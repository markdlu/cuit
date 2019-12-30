##########################################################
#!/bin/bash                                              #
#                                                        #
# History:                                               #
# Mark Lu      12/08/2017   initiliazed                  #
#                                                        #
#                                                        #
##########################################################
. ~/set_env.sh $1
DT_FMT="%d%m%Y-%H:%M:%S"
START_TIME=`date +${DT_FMT}`
SCRIPT_HOME=/usr/local/lib/service/cuorsa/ml4147/mydev/rman
ORACLE_SID=$1
LOGLOC=$SCRIPT_HOME/logs
LOGFILE=$LOGLOC/rman_duplicate_${ORACLE_SID}_${START_TIME}.log
export EMAIL=ml4147@columbia.edu
export V_PASSWD=`grep "rman1t:rman" ~/.getpw.lst|cut -f 3 -d ':'`
export SUBJECT_SUCCESS="SUCCESS:$ORACLE_SID Duplication completed"
export SUBJECT_FAIL="FAILED:$ORACLE_SID Duplicaton Failed"
echo "shutting down database ...."
sqlplus "/as sysdba" << EOF
shutdown abort;
exit;
EOF
#echo "Dropping database and Removing data files......"
sqlplus "/as sysdba" << EOF
startup mount exclusive restrict pfile=init${ORACLE_SID}_forclone.ora;
drop database ;
exit;
EOF
echo " "
sqlplus "/as sysdba" << EOF
startup nomount pfile=init${ORACLE_SID}_forclone.ora
exit;
EOF
echo "Starting RMAN DUPLICATE ..."
rman auxiliary / catalog rman/${V_PASSWD}@rman1t cmdfile=rman_dup_${ORACLE_SID}.rman log=$LOGFILE
wait
sleep 180
if [ ! -d $LOGLOC ]
then
mkdir -p $LOGLOC
fi 
cat $LOGFILE | grep -E "ORA-|RMAN-" > $LOGLOC/tmp.txt
#if [ -s $LOGLOC/tmp.txt ]
#then
#echo " Errors found with duplicate .."
#/bin/mailx -s "$SUBJECT_FAIL" $EMAIL < $LOGFILE
#else
#/bin/mailx -s "$SUBJECT_SUCCESS" $EMAIL < $LOGFILE
#fi
#rm -f $LOGLOC/tmp.txt
exit
