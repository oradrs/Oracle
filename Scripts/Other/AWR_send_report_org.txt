#!/usr/bin/ksh
#==============================================================================
# File: run_awr.ksh
# Type: korn shell script
# Author: Tim Gorman (Evergreen Database Technologies -- www.evdbt.com)
# Date: 12sep08
#
# Description:
# UNIX Korn-shell script to run under the UNIX "cron" utility to
# automatically generate and email Oracle "AWR" reports in HTML against
# the database accessed via the specified TNS connect-string, to a
# specified list of email addresses.
#
# Parameters:
# Zero, one, or more parameters may be passed. These parameters
# are TNS connect-strings, each of which refer to entries in the
# script's configuration file (named ".run_awr", described below).
#
# If no parameters are specified, then the script processes all of
# the lines in the configuration file.
#
# For each of the parameters specified, the script will process
# each of the corresponding lines in the configuration file.
#
# Each TNS connect-string should be separated by whitespace.
#
# Configuration file:
# The file ".run_awr" in the "$HOME" directory contains one or more
# lines with the following format, three fields delimited by "commas":
#
# TNS-connect-string : recipient-list : hrs
#
# where:
#
# TNS-connect-string Oracle TNS connect-string for the db
# recipient-list comma-separated list of email addresses
# hrs "sysdate - <hrs>" is the beginning
# time of the AWR report and "sysdate"
# is the ending time of the AWR report
#
# Modification history:
#==============================================================================
# Updated by:  Kellyn Pedersen for I-Behavior
# Date:  3/8/10
# Modification:  Added setup environment variables and such for I-Behavior
# OK, lots of changes...:)  Changed from columns in sql to variables in shell to populate.
# Changed email piece to function correctly with our way of using Linux mail
# Changed to reads on the vars to give us the vars we want.
# USAGE:  ./run_awr.ksh <ORACLE_SID>  (If you want to run awr's for all db's in .run_awr, don't list SID!)
# Dependencies: .run_awr
#
#------------------------------------------------------------------------------
# Set up Oracle environment variables...
#------------------------------------------------------------------------------
. /home/oracle/.kprofile
export ORACLE_SID=$1

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=`grep -i ^"$ORACLE_SID" /etc/oratab | awk -F: '{print $2}'`
export PATH=$PATH:${ORACLE_HOME}/bin

EXEC_DIR=/common/db_scripts/admin
LOG_DIR=/common/db_scripts/logs
export EXEC_DIR LOG_DIR 

echo $ORACLE_SID $ORACLE_HOME $EXEC_DIR $LOG_DIR
#
#------------------------------------------------------------------------------
# Verify that the Oracle environment variables and directories are set up...
#------------------------------------------------------------------------------
if [[ "${ORACLE_HOME}" = "" ]]
then
echo "ORACLE_HOME not set; aborting..."
exit 1
fi
if [ ! -d ${ORACLE_HOME} ]
then
echo "Directory \"${ORACLE_HOME}\" not found; aborting..."
exit 1
fi
if [ ! -d ${ORACLE_HOME}/bin ]
then
echo "Directory \"${ORACLE_HOME}/bin\" not found; aborting..."
exit 1
fi
if [ ! -x ${ORACLE_HOME}/bin/sqlplus ]
then
echo "Executable \"${ORACLE_HOME}/bin/sqlplus\" not found; aborting..."
exit 1
fi
if [ ! -x ${ORACLE_HOME}/bin/tnsping ]
then
echo "Executable \"${ORACLE_HOME}/bin/tnsping\" not found; aborting..."
exit 1
fi
#
#------------------------------------------------------------------------------
# Set shell variables used by the shell script...
#------------------------------------------------------------------------------
export _Pgm=run_awr
export _RunAwrListFile=${EXEC_DIR}/.run_awr
if [ ! -r ${_RunAwrListFile} ]
then
echo "Script configuration file \"${_RunAwrListFile}\" not found; aborting..."
exit 1
fi
#
#------------------------------------------------------------------------------
# ...loop through the list of database instances specified in the ".run_awr"
# list file...
#
# Entries in this file have the format:
#
# dbname:rcpt-list:hrs
#
# where:
# dbname - is the TNS connect-string of the database instance
# rcpt-list - is a comma-separated list of email addresses
# hrs - is the number of hours (from the present time)
# marking the starting point of the AWR report
#------------------------------------------------------------------------------
grep -v "^#" ${_RunAwrListFile} | awk -F: '{print $1" "$2" "$3}' | \
while read _ListDb _ListRcpts _ListHrs
do
#----------------------------------------------------------------------
# If command-line parameters were specified for this script, then they
# must be a list of databases...
#----------------------------------------------------------------------
if (( $# > 0 ))
then
#
#---------------------------------------------------------------
# If a list of databases was specified on the command-line of
# this script, then find that database's entry in the ".run_awr"
# configuration file and retrieve the list of email recipients
# as well as the #-hrs for the AWR report...
#---------------------------------------------------------------
_Db=""
_Rcpts=""
_Hrs=""
for _SpecifiedDb in $*
do
#
if [[ "${_ListDb}" = "${_SpecifiedDb}" ]]
then
_Db=${_ListDb}
_Rcpts=${_ListRcpts}
_Hrs=${_ListHrs}
fi
#
done
#
#---------------------------------------------------------------
# if the listed DB is not specified on the command-line, then
# go onto the next listed DB...
#---------------------------------------------------------------
if [[ "${_Db}" = "" ]]
then
continue
fi
#---------------------------------------------------------------
else # ...else, if no command-line parameters were specified, then
# just use the information in the ".run_awr" configuration file...
#---------------------------------------------------------------
_Db=${_ListDb}
_Rcpts=${_ListRcpts}
_Hrs=${_ListHrs}
#
fi
#
#----------------------------------------------------------------------
# Verify that the name of the database is a valid TNS connect-string...
#----------------------------------------------------------------------
${ORACLE_HOME}/bin/tnsping ${_Db} > /dev/null 2>&1
if (( $? != 0 ))
then
echo "\"tnsping ${_Db}\" failed; aborting..."
exit 1
fi
#
#----------------------------------------------------------------------
# Create script variables for the output files...
#----------------------------------------------------------------------
export _Db _Rcpts _Hrs _ListDb _ListRcpts _ListHrs
echo $_ListDb $_ListRcpts $_ListHrs
_TmpSpoolFile="${LOG_DIR}/${_Pgm}_${_Db}.tmp"
_AwrReportFile="${LOG_DIR}/${_Pgm}_${_Db}.html"
export _TmpSpoolFile _AwrReportFile
echo $_TmpSpoolFile $_AwrReportFile
#
#----------------------------------------------------------------------
# Call SQL*Plus, retrieve some database instance information, and then
# call the AWR report as specified...
#----------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus -s '/as sysdba' << EOF | read P_DBID
set echo off feedback off timing off pagesize 0 linesize 300 trimspool on verify off heading off
select dbid from v\$database;
EOF
export P_DBID

${ORACLE_HOME}/bin/sqlplus -s '/as sysdba' << EOF | read P_INST
set echo off feedback off timing off pagesize 0 linesize 300 trimspool on verify off heading off
WHENEVER OSERROR EXIT;
WHENEVER SQLERROR EXIT;
select instance_number from v\$instance;
EOF
export P_INST

${ORACLE_HOME}/bin/sqlplus -s '/as sysdba' << EOF | read P_BID
set echo off feedback off timing off pagesize 0 linesize 300 trimspool on verify off heading off
WHENEVER OSERROR EXIT;
WHENEVER SQLERROR EXIT;
select min(snap_id) snap_id
from dba_hist_snapshot
where end_interval_time >= (sysdate-(${_Hrs}/24))
and startup_time <= begin_interval_time
and dbid =${P_DBID}
and instance_number =${P_INST};
EOF
export P_BID

${ORACLE_HOME}/bin/sqlplus -s '/as sysdba' << EOF | read P_EID
set echo off feedback off timing off pagesize 0 linesize 300 trimspool on verify off heading off
WHENEVER OSERROR EXIT;
WHENEVER SQLERROR EXIT;
select max(snap_id) snap_id
from dba_hist_snapshot
where dbid =${P_DBID}
and instance_number =${P_INST};
EOF
export P_EID
echo $P_DBID $P_INST $P_BID $P_EID

${ORACLE_HOME}/bin/sqlplus -s '/as sysdba' << EOF 
set echo off feedback off timing off pagesize 0 linesize 300 trimspool on verify off heading off
WHENEVER OSERROR EXIT;
WHENEVER SQLERROR EXIT;
spool ${_TmpSpoolFile}
select 'BEGIN='||trim(to_char(begin_interval_time, 'HH24:MI')) snap_time
from dba_hist_snapshot
where dbid =${P_DBID}
and instance_number =${P_INST}
and snap_id =${P_BID};
select 'END='||trim(to_char(end_interval_time, 'HH24:MI')) snap_time
from dba_hist_snapshot
where dbid =${P_DBID}
and instance_number =${P_INST}
and snap_id =${P_EID};
spool off

select output from table(dbms_workload_repository.awr_report_html(${P_DBID}, ${P_INST}, ${P_BID}, ${P_EID}, 0));

spool ${_AwrReportFile}
/
exit success
EOF
#
#----------------------------------------------------------------------
# Determine if the "start time" and "end time" of the AWR report was
# spooled out...
#----------------------------------------------------------------------
if [ -f ${_TmpSpoolFile} ]
then
_BTstamp=`grep '^BEGIN=' ${_TmpSpoolFile} | awk -F= '{print $2}'`
_ETstamp=`grep '^END=' ${_TmpSpoolFile} | awk -F= '{print $2}'`
export _TBstamp _ETstamp
fi
#
#----------------------------------------------------------------------
# Determine if an AWR report was spooled out...
#----------------------------------------------------------------------
if [ -f ${_AwrReportFile} ]
then
 echo | uuencode ${_AwrReportFile} ${_AwrReportFile} | mailx -s "AWR Report for ${_Db} (${_BTstamp}-${_ETstamp} GMT)" ${_Rcpts}  
fi
#
rm -f ${_AwrReportFile} ${_TmpSpoolFile}
#
done
#
#------------------------------------------------------------------------------
# Finish up...
#------------------------------------------------------------------------------
exit 0


