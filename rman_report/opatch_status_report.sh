#!/bin/bash

###############################################################################################
#  This script checks the Opatch status.
# usage:
#
##
###############################################################################################


###############################################################################################
. ~/set_env.sh patch1t 

ORACLE_SID=emrep1p
DATETIME=`date '+%Y%m%d'`; export DATETIME
HOST=`hostname`; export HOST
OUT=/tmp/report.out; export OUT
TODAY=`date '+%m/%d/%Y'`
MAILTO=ml4147@columbia.edu
export V_PASSWD=`grep "emrep1p:dbadmsa" ~/.getpw.lst|cut -f 3 -d ':'`
export script_dir=$(dirname $0)

rm $OUT
echo "All Oracle DBAs," | tee -a $OUT
echo "" | tee -a $OUT
echo "Please view attached file for weekly Oracle patch status generated from OEM - on today " $TODAY  | tee -a $OUT
echo "" | tee -a $OUT
echo "(This report is generated from '${script_dir}/opatch_status_report.sh')" | tee -a $OUT
echo "" | tee -a $OUT
echo "" | tee -a $OUT
echo "Regards," | tee -a $OUT
echo "" | tee -a $OUT

sqlplus dbadmsa/${V_PASSWD}@${ORACLE_SID} <<EOF

@${script_dir}/opatch_status_report.sql ${DATETIME} ${script_dir}

exit
EOF
# echo | mutt -s 'Oracle Patch Monthly Status' -a ${script_dir}/output/database/opatch_status_report_${DATETIME}.csv wp2139@columbia.edu < $OUT
# echo | mutt -s 'Weekly Patch Status - Oracle Databases' -a ${script_dir}/output/database/opatch_status_report_${DATETIME}.csv ${MAILTO} < $OUT

mailx -s 'Weekly Patch Status from OEM Data  - Oracle Databases' -a ${script_dir}/output/database/opatch_status_report_${DATETIME}.csv ${MAILTO} < $OUT

rm $OUT
# rm ${script_dir}/output/database/opatch_status_report_${DATETIME}.csv
exit

