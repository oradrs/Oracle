# Source : https://gist.github.com/dotmaik1/777026ec8a593454f4d1de68087020b4


05 8-17 * * 1-5 /dbms/oracle/local/AMCMPRN1/etc/Scripts/awrreport_html_hourly.ksh AMCMPRN1 > /tmp/AWR_report_AMCMPRN1.out  2>&1
08 8-17 * * 1-5 /dbms/oracle/local/AMCMPRN1/etc/Scripts/addmreport_hourly.ksh AMCMPRN1 > /tmp/addm_report_AMCMPRN1.out  2>&1
05 8-17 * * 1-5 /dbms/oracle/monitor/bin/ashreport_html_hourly.ksh -sAMCMPRN1 -t60 > /tmp/AWR_report_AMCMPRN1.out  2>&1



AWR:


oracle@mwamdb3p[DUMMY] /home/oracle => cat /dbms/oracle/local/AMCMPRN1/etc/Scripts/awrreport_html_hourly.ksh
#!/bin/ksh
# |
# | DESCRIPTION
# |  Generate AWR report for yesterday (works on 10g only ).
# |
# | USAGE
# |   awrreport.ksh ORACLE_SID
# |
# | Modified:
# |   Taras Hryvnak
# |   Giridhar Varre Venkata Sai - Fixed to work in 11g,11gR2
# | Date
# |   06/08/2006
# |   07/14/2013
# |
PATH=/usr/local/bin:/usr/bin:/usr/sbin:$PATH

program=`basename $0`
usage="\t$program ORACLE_SID"

if [ $# -lt 1 ];
then
   echo ""
   echo "$program: too few arguments specified."
   echo ""
   echo "$usage"
   echo ""
   exit 1;
fi

ORACLE_SID="$1"
ORA_ENVFILE=/dbms/oracle/local/${ORACLE_SID}/etc/${ORACLE_SID}.env
LOG_DIR=/backup/${ORACLE_SID}/logs
AWRREPORT_DIR=/backup/${ORACLE_SID}/spreport

#
# setup the environment for Oracle
#

if [ ! -f $ORA_ENVFILE ]
then
       echo "Oracle environment file for database ${ORACLE_SID} is not found in
/dbms/oracle/local/${ORACLE_SID}"
       exit 1;
else
   . $ORA_ENVFILE
fi

if [ ! -d ${LOG_DIR} ]
then
        mkdir -p ${LOG_DIR}
fi

if [ ! -d ${AWRREPORT_DIR} ]
then
        mkdir -p ${AWRREPORT_DIR}
fi

now=`date +%d-%m-%Y.%H:%M:%S`
export now

export log=/backup/${ORACLE_SID}/logs/addreport_${ORACLE_SID}_${now}.log

echo "${now}: Start : AWR report for ${ORACLE_SID}" >> $log

cd ${AWRREPORT_DIR}

sqlplus /nolog<<!
connect / as sysdba

-- Checking Oracle versioN first
whenever sqlerror exit;
declare
l_ver varchar2(2);
begin
    SELECT substr(version, 1,2) INTO l_ver  FROM v\$INSTANCE;
    IF l_ver < '10' THEN
        raise_application_error(-20200,
      'Error: Database/Instance has version '||l_ver||' . Minimum Version required is 10.1');
    END IF;
end;
/

whenever sqlerror continue;

column c_report_name    new_valu  report_name
column c_report_type    new_value report_type
column c_begin_snap     noprint new_value begin_snap
column c_end_snap       noprint new_value end_snap

set pagesize 0 termout off echo off
spool tmpname
select 'awrreport.' || instance_name  || '.' || trunc(sysdate - 1)||'.html' c_report_name, 'html' c_report_type
from v\$instance
/

spool off

select max(snap_id-1) c_begin_snap, max(snap_id) c_end_snap
from dba_hist_snapshot
/
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
!

exit_code=$?

# In case of Failure
if [ "$exit_code" != 0 ]
then
 status=FAILURE
else
 status=SUCCESS
fi

now=`date +%d-%m-%Y.%H:%M:%S`
echo "${now}: Finish: AWR report for ${ORACLE_SID}" >> $log

report_file=`cat tmpname.lst|grep awrreport.${ORACLE_SID}|cut -c 1-33`
#######rm tmpname.lst


#export MAILTO="gv12622@imcnam.ssmb.com"
export MAILTO="jp66979@imcnam.ssmb.com,vg74580@imcnam.ssmb.com,ps13876@imcnam.ssmb.com,pp65478@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,vk87205@imcnam.ssmb.com,sk90410@imcnam.ssmb.com,ad15215@imcnam.ssmb.com,bs74739@imcnam.ssmb.com,sg14775@imcnam.ssmb.com,as68614@imcnam.ssmb.com,sk98215@imcnam.ssmb.com,km01759@imcnam.ssmb.com,gm21731@imcnam.ssmb.com,rb89619@imcnam.ssmb.com,cn76131@imcnam.ssmb.com,vs53017@imcnam.ssmb.com,ys14880@imcnam.ssmb.com,hy51109@imcnam.ssmb.com,pc44637@imcnam.ssmb.com,dk99799@imcnam.ssmb.com,dz63729@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,ak17178@imcnam.ssmb.com"
export CONTENT=$report_file
export SUBJECT=$report_file
(
 echo "Subject: CITICMT $SUBJECT"
 echo "MIME-Version: 1.0"
 echo "Content-Type: text/html"
 echo "Content-Disposition: inline"
 cat $CONTENT
) | /usr/sbin/sendmail $MAILTO



ASH:

oracle@mwamdb3p[DUMMY] /home/oracle => cat /dbms/oracle/local/AMCMPRN1/etc/Scripts/addmreport_hourly.ksh
#!/bin/ksh
# |
# | DESCRIPTION
# |  Generate ADDM report for yesterday (works on 10g only ).
# |
# | USAGE
# |   addmreport.ksh ORACLE_SID
# |
# | Modified:
# |   Taras Hryvnak
# |   Giridhar Varre Venkata Sai - Updated to work on 11g,11gR2
# | Date
# |   06/08/2006
# |

PATH=/usr/local/bin:/usr/bin:/usr/sbin:$PATH

program=`basename $0`
usage="\t$program ORACLE_SID"

if [ $# -lt 1 ];
then
   echo ""
   echo "$program: too few arguments specified."
   echo ""
   echo "$usage"
   echo ""
   exit 1;
fi

ORACLE_SID="$1"
ORA_ENVFILE=/dbms/oracle/local/${ORACLE_SID}/etc/${ORACLE_SID}.env
LOG_DIR=/backup/${ORACLE_SID}/logs
ADDMREPORT_DIR=/backup/${ORACLE_SID}/spreport

#
# setup the environment for Oracle
#

if [ ! -f $ORA_ENVFILE ]
then
       echo "Oracle environment file for database ${ORACLE_SID} is not found in
/dbms/oracle/local/${ORACLE_SID}"
       exit 1;
else
   . $ORA_ENVFILE
fi

if [ ! -d ${LOG_DIR} ]
then
        mkdir -p ${LOG_DIR}
fi

if [ ! -d ${ADDMREPORT_DIR} ]
then
        mkdir -p ${ADDMREPORT_DIR}
fi

now=`date +%d-%m-%Y.%H:%M:%S`
export now

export log=/backup/${ORACLE_SID}/logs/addreport_${ORACLE_SID}_${now}.log

echo "${now}: Start : ADDM report for ${ORACLE_SID}" >> $log

cd ${ADDMREPORT_DIR}

sqlplus /nolog<<!
connect / as sysdba

-- Checking Oracle versioN first
whenever sqlerror exit;
declare
l_ver varchar2(2);
begin
    SELECT substr(version, 1,2) INTO l_ver  FROM v\$INSTANCE;
    IF l_ver < '10' THEN
        raise_application_error(-20200,
      'Error: Database/Instance has version '||l_ver||' . Minimum Version required is 10.1');
    END IF;
end;
/

whenever sqlerror continue;

column c_report_name    new_value  report_name
column c_report_type    new_value report_type
column c_begin_snap     noprint new_value begin_snap
column c_end_snap       noprint new_value end_snap

set pagesize 0 termout off echo off
spool tmpname
select 'addmreport.' || instance_name  || '.' || trunc(sysdate - 1)||'.rpt' c_report_name, 'text' c_report_type
from v\$instance
/

spool off

select max(snap_id-1) c_begin_snap, max(snap_id) c_end_snap
from dba_hist_snapshot
/
@$ORACLE_HOME/rdbms/admin/addmrpt.sql
!

exit_code=$?

# In case of Failure
if [ "$exit_code" != 0 ]
then
 status=FAILURE
else
 status=SUCCESS
fi

now=`date +%d-%m-%Y.%H:%M:%S`
echo "${now}: Finish: ADDM report for ${ORACLE_SID}" >> $log

report_file=`cat tmpname.lst|grep addmreport.${ORACLE_SID}|cut -c 1-33`
rm tmpname.lst

# Notify COE or other personel through email
cat $report_file | mailx -s "CITICMT $report_file" jp66979@imcnam.ssmb.com,vg74580@imcnam.ssmb.com,ps13876@imcnam.ssmb.com,pp65478@imcnam.ssmb.com,vk87205@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,ad15215@imcnam.ssmb.com,sk90410@imcnam.ssmb.com,bs74739@imcnam.ssmb.com,sg14775@imcnam.ssmb.com,as68614@imcnam.ssmb.com,sk98215@imcnam.ssmb.com,km01759@imcnam.ssmb.com,gm21731@imcnam.ssmb.com,rb89619@imcnam.ssmb.com,cn76131@imcnam.ssmb.com,vs53017@imcnam.ssmb.com,ys14880@imcnam.ssmb.com,hy51109@imcnam.ssmb.com,pc44637@imcnam.ssmb.com,dk99799@imcnam.ssmb.com,dz63729@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,ak17178@imcnam.ssmb.com
exit



ADDM:

oracle@mwamdb3p[DUMMY] /home/oracle => cat /dbms/oracle/monitor/bin/ashreport_html_hourly.ksh
#!/bin/ksh
#***********************************************************************************
#
# generate_ash_report_for_given_database.ksh
#
# Script to generate a html ash report and send email to the DBA
#   Syntax: generate_ash_report_for_given_database.ksh -s<sid> -t<In_Minutes_The_ASH_Report_Will_Be_Run_For_Begin_Time_Of_SYSDATE_Minus_ThisTime>
#
#   Output: To standard out.
#
# Modification:
#***********************************************************************************

typeset -u fsid
function usage {
print "Usage: generate_ash_report_for_given_database.ksh -s<sid>  "
echo " generate_ash_report_for_given_database.ksh -s<sid> -t<In_Minutes_The_ASH_Report_Will_Be_Run_For_Begin_Time_Of_SYSDATE_Minus_Minutes> "
echo  " Example would be generate_ash_report_for_given_database.ksh -sCEHRDVMN1 -t60"
}

#***********************************************************************************
# get the options from the command line.
# if an unknown option is passed, print out the usage.
#***********************************************************************************
if [[ $# -ne 2 ]]
then
  usage;
  exit;
fi
while getopts  s:t: parm;
  do
    case $parm in
      s)
        fsid="$OPTARG";;
      t)
        fmin="$OPTARG";;
      ?)
        usage;
        exit;;
    esac
  done

#***********************************************************************************
# define and export variables
#***********************************************************************************
SID=$fsid
ORACLE_SID=$fsid
export ORACLE_SID
BEGIN_TIME=$fmin
export BEGIN_TIME
DOW=$(date '+%m%d%H%M%S')
ORA_ENVFILE=/dbms/oracle/local/${ORACLE_SID}/etc/${ORACLE_SID}.env
export ORA_ENVFILE
. $ORA_ENVFILE

DIR=/dbms/oracle/local/${ORACLE_SID}/etc/Scripts/output/${ORACLE_SID}
export DIR
export PSFT_OUT=/dbms/oracle/local/${ORACLE_SID}/etc/Scripts
if [[ -d $PSFT_OUT/output/${ORACLE_SID} ]]
then
 echo " "
else mkdir -p $PSFT_OUT/output/${ORACLE_SID}
fi

trap 'exit' 1 2 3
case $ORACLE_TRACE in
 T) set -x ;;
esac

#*****************************************************************
# THIS IS THE LOGIC
#*****************************************************************

SPOOLOUTA=/tmp/test_${ORACLE_SID}_a.lst
$ORACLE_HOME/bin/sqlplus -S / as sysdba  <<EOF
set linesize 300;
set pagesize 2000;
set heading on
spool $SPOOLOUTA
set pagesize 0 feedback off verify off heading off echo off
set pages 0;
set feedback off
SELECT s.snap_id SNAP_ID
FROM dba_hist_snapshot s, dba_hist_database_instance di
WHERE di.dbid = s.dbid
AND di.instance_number = s.instance_number
AND di.startup_time = s.startup_time
ORDER BY snap_id;
spool off;
quit
EOF

SPOOLOUTB=/tmp/test_${ORACLE_SID}_b.lst
$ORACLE_HOME/bin/sqlplus -S / as sysdba  <<EOF
set linesize 300;
set pagesize 2000;
set heading on
spool $SPOOLOUTB
set pagesize 0 feedback off verify off heading off echo off
set pages 0;
set feedback off
SELECT s.snap_id SNAP_ID
FROM dba_hist_snapshot s, dba_hist_database_instance di
WHERE di.dbid = s.dbid
AND di.instance_number = s.instance_number
AND di.startup_time = s.startup_time
ORDER BY snap_id;
spool off;
quit
EOF

tail -2 /tmp/test_${ORACLE_SID}_a.lst >/tmp/test_${ORACLE_SID}_aqa.lst
BEGIN_SNAP=`head -1 /tmp/test_${ORACLE_SID}_aqa.lst`
END_SNAP=`tail -1 /tmp/test_${ORACLE_SID}_b.lst`

DB_ID=`sqlplus -s /nolog << EOF
      conn / as sysdba
     set pagesize 0 feedback off verify off heading off echo off
      select dbid from v\\$database;
exit;
EOF`

echo "define  report_type   = 'html' " >/tmp/precheck_ash_${ORACLE_SID}.sql
echo "define  begin_time   = '-$fmin' " >>/tmp/precheck_ash_${ORACLE_SID}.sql
echo "define  duration   = '' " >>/tmp/precheck_ash_${ORACLE_SID}.sql
echo "define  report_name  = /tmp/ash_report_${ORACLE_SID}.lst " >>/tmp/precheck_ash_${ORACLE_SID}.sql
echo " " >>/tmp/precheck_ash_${ORACLE_SID}.sql

SPOOLOUT=${DIR}/ASH_REPORT_FOR_${ORACLE_SID}_CREATED_ON_${DOW}.lst
$ORACLE_HOME/bin/sqlplus -S / as sysdba  <<EOF
--set linesize 300;
--set pagesize 2000;
--set heading on
spool $SPOOLOUT
select name,dbid from v\$database;
@/tmp/precheck_ash_${ORACLE_SID}.sql
@@?/rdbms/admin/ashrpt.sql
spool off;
quit
EOF

cat /tmp/ash_report_${ORACLE_SID} >>${DIR}/ASH_REPORT_FOR_${ORACLE_SID}_CREATED_ON_${DOW}.lst

export MAILTO="jp66979@imcnam.ssmb.com,vg74580@imcnam.ssmb.com,ps13876@imcnam.ssmb.com,pp65478@imcnam.ssmb.com,vk87205@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,dl.ces.na.it.dba@imcnam.ssmb.com,sk90410@imcnam.ssmb.com,ad15215@imcnam.ssmb.com,bs74739@imcnam.ssmb.com,sg14775@imcnam.ssmb.com,as68614@imcnam.ssmb.com,sk98215@imcnam.ssmb.com,km01759@imcnam.ssmb.com,gm21731@imcnam.ssmb.com,rb89619@imcnam.ssmb.com,cn76131@imcnam.ssmb.com,vs53017@imcnam.ssmb.com,ys14880@imcnam.ssmb.com,hy51109@imcnam.ssmb.com,pc44637@imcnam.ssmb.com,dk99799@imcnam.ssmb.com,dz63729@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,sp62175@imcnam.ssmb.com,rr78044@imcnam.ssmb.com,rb36401@imcnam.ssmb.com,ak17178@imcnam.ssmb.com"
export CONTENT=/tmp/ash_report_${ORACLE_SID}.lst
export SUBJECT="CITICMT : ASH Report for $ORACLE_SID at ${DOW}"
(
 echo "Subject: $SUBJECT"
 echo "MIME-Version: 1.0"
 echo "Content-Type: text/html"
 echo "Content-Disposition: inline"
 cat $CONTENT
) | /usr/sbin/sendmail $MAILTO




exit 3
fi

cd ${DIR}
find  . -type f -name "ASH_REPORT_FOR_*.lst" -mtime +1 -exec rm -f {} \;
exit
