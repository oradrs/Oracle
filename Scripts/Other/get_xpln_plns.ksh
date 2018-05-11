#!/usr/bin/ksh

######################################################################
#get_xpln_plns.ksh
#Execution:  ./get_xpln_plns.ksh $ORACLE_SID
#Author:  Kellyn Pot'Vin
######################################################################

ORACLE_SID=$1
export ORACLE_SID

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=`grep -i ^"$ORACLE_SID" /etc/oratab | awk -F: '{print $2}'`
export PATH=$PATH:${ORACLE_HOME}/bin


EXEC_DIR=/common/db_scripts/admin
SQL_DIR=/common/db_scripts/sql
LOG_DIR=/common/db_scripts/logs
export EXEC_DIR SQL_DIR LOG_DIR
XPLN_LOG=${LOG_DIR}/get_xln_plns_${ORACLE_SID}.log
LTST_SQL=${SQL_DIR}/ltst_sql_ids.sql
export XLPN_LOG LTST_SQL


#Remove previous scripts which is dynamically generated.
rm -f ${XPLN_LOG}
rm -f ${LTST_SQL}
touch ${XPLN_LOG}


#Create and Run scripts
##Create script for SQLTXlite run
${ORACLE_HOME}/bin/sqlplus '/as sysdba' <<EOF
set head off;
set pagesize 500;
set linesize 500;
select distinct 'select * from table(dbms_xplan.display_awr('''||sql_id||'''));' from v\$sql
where fetches >10
and sharable_mem > 10000
and sql_text not like '%opt_param%'
and parsing_schema_id not in (0,24,5)
and sql_id in (select distinct(sql_id) from DBA_HIST_SQLTEXT);
spool ${LTST_SQL};
/
spool off;
EOF

#Run Scripts
$ORACLE_HOME/bin/sqlplus '/as sysdba' <<EOF>>${XPLN_LOG}
@${LTST_SQL};
exit
EOF
  echo|mail -s "Latest SQL Explain Plans Collected for $ORACLE_SID" "kpedersen@i-behavior.com" <${XPLN_LOG}

