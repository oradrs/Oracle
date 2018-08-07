# ################################################################################################################
# DATABASE DAILY HEALTH CHECK MONITORING SCRIPT
VER="[4.3]"
# ===============================================================================
# CAUTION:
# THIS SCRIPT MAY CAUSE A SLIGHT PERFORMANCE IMPACT WHEN IT RUN,
# I RECOMMEND TO NOT RUN THIS SCRIPT SO FREQUENT.
# E.G. YOU MAY CONSIDER TO SCHEDULE IT TO RUN ONE TIME BETWEEN 12:00AM to 5:00AM.
# ===============================================================================
#
# FEATURES:
# CHECKING CPU UTILIZATION.
# CHECKING FILESYSTEM UTILIZATION.
# CHECKING TABLESPACES UTILIZATION.
# CHECKING FLASH RECOVERY AREA UTILIZATION.
# CHECKING ASM DISKGROUPS UTILIZATION.
# CHECKING BLOCKING SESSIONS ON THE DATABASE.
# CHECKING UNUSABLE INDEXES ON THE DATABASE.
# CHECKING INVALID OBJECTS ON THE DATABASE.
# CHECKING CORRUPTED BLOCKS ON THE DATABASE.
# CHECKING FAILED JOBS IN THE DATABASE.
# CHECKING LONG RUNNING JOBS [For More than 1 Day].
# CHECKING ACTIVE INCIDENTS.
# CHECKING OUTSTANDING ALERTS.
# CHECKING DATABASE SIZE GROWTH.
# CHECKING RMAN BACKUPs.
# CHECKING OS / HARDWARE STATISTICS.
# CHECKING RESOURCE LIMITS.
# CHECKING RECYCLEBIN.
# CHECKING CURRENT RESTORE POINTS.
# CHECKING HEALTH MONITOR CHECKS RECOMMENDATIONS THAT RUN BY DBMS_HM PACKAGE.
# CHEKCING MONITORED INDEXES.
# CHECKING REDOLOG SWITCHES.
# CHECKING MODIFIED INTIALIZATION PARAMETERS SINCE THE LAST DB STARTUP.
# CHECKING ADVISORS RECOMMENDATIONS:
#	   - SQL TUNING ADVISOR
#	   - SGA ADVISOR
#	   - PGA ADVISOR
#	   - BUFFER CACHE ADVISOR
#	   - SHARED POOL ADVISOR
#	   - SEGMENT ADVISOR
# CHECKING NEW CREATED OBJECTS.
# CHECKING AUDIT RECORDS.
# CHECKING FAILED LOGIN ATTEMPTS.
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# 				    #   #   # #   #  
#
# Created:      22-12-13 Based on dbalarm.sh script.
# Modifications:18-05-14 Added Filsystem monitoring.
#		19-05-14 Added CPU monitoring.
#		09-12-14 Added Tablespaces monitoring
#			 Added BLOCKING SESSIONS monitoring
#			 Added UNUSABLE INDEXES monitoring 
#			 Added INVALID OBJECTS monitoring
#			 Added FAILED LOGINS monitoring
#			 Added AUDIT RECORDS monitoring
#			 Added CORRUPTED BLOCKS monitoring
#			 [It will NOT run a SCAN. It will look at V$DATABASE_BLOCK_CORRUPTION]
#			 Added FAILED JOBS monitoring.
#		06-10-15 Replaced mpstat with iostat for CPU Utilization Check
#		02-11-15 Enhanced "FAILED JOBS monitoring" part.
#               13-12-15 Added Advisors Recommendations to the report
#               04-04-16 dba_tablespace_usage_metrics view will be used for 11g onwards versions
#                        for checking tablespaces size, advised by: Satyajit Mohapatra
#               10-04-16 Add Flash Recovery Area monitoring
#               10-04-16 Add ASM Disk Groups monitoring
#		15-07-16 Add ACTIVE INCIDENTS, RESOURCE LIMITS, RECYCLEBIN, RESTORE POINTS,
#			  MONITORED INDEXES, REDOLOG SWITCHES, MODIFIED SPFILE PARAMETERS checks.
#		02-01-17 Removed ALERTLOG check for DB & Listener +
#			 Merged alerts with advisors. 		[Recommended by: ABD-ELGAWAD]
#		03-01-17 Added checking RAC status feature. 	[Recommended by: Samer ALJazzar]
#		09-01-17 Added RMAN BACKUP CHECK.
#		04-05-17 Added Reporting of Newly Created Objects in the last 24Hours.
#		12-06-17 Added Long Running Jobs Alert.
#		20-07-17 Neutralize login.sql if found under Oracle user home directory due to bugs.
#               10-10-17 Added reporting Long Running Queries to the report.
#		09-01-18 Workaround for df command bug "`/root/.gvfs': Permission denied"
#		16-05-18 Added SHOWSQLTUNINGADVISOR, SHOWMEMORYADVISORS, SHOWSEGMENTADVVISOR, SHOWJOBS
#			 and SHOWHASHEDCRED parameters to allow the user to decide whether to show their
#			 results in the report or not.
#		21-06-18 Added MODOBJCONTTHRESHOLD to control the display of LAST MODIFIED OBJECTS in the report.
#
#
#
#
#
# ################################################################################################################
MAIL_LIST="youremail@yourcompany.com"

	case ${MAIL_LIST} in "youremail@yourcompany.com")
	 echo
	 echo "##############################################################################################"
	 echo "You Missed Something :-)"
	 echo "In order to receive the HEALTH CHECK report via Email, you have to ADD your E-mail at line# 90"
	 echo "by replacing this template [youremail@yourcompany.com] with YOUR E-mail address."
	 echo "DB HEALTH CHECK report will be saved on disk..."
	 echo "##############################################################################################"
	 export SQLLINESIZE=165
	 echo;;
	 *) export SQLLINESIZE=200;;
	esac

SCRIPT_NAME="dbdailychk${VER}"
SRV_NAME=`uname -n`

# #########################
# THRESHOLDS:
# #########################
# Send an E-mail for each THRESHOLD if been reached:
# ADJUST the following THRESHOLD VALUES as per your requirements:

FSTHRESHOLD=95		# THRESHOLD FOR FILESYSTEM %USED				[OS]
CPUTHRESHOLD=95		# THRESHOLD FOR CPU %UTILIZATION				[OS]
TBSTHRESHOLD=95		# THRESHOLD FOR TABLESPACE %USED				[DB]
FRATHRESHOLD=95         # THRESHOLD FOR FLASH RECOVERY AREA %USED       		[DB]
ASMTHRESHOLD=95         # THRESHOLD FOR ASM DISK GROUPS                 		[DB]
UNUSEINDXTHRESHOLD=1    # THRESHOLD FOR NUMBER OF UNUSABLE INDEXES			[DB]
INVOBJECTTHRESHOLD=1    # THRESHOLD FOR NUMBER OF INVALID OBJECTS			[DB]
FAILLOGINTHRESHOLD=1    # THRESHOLD FOR NUMBER OF FAILED LOGINS				[DB]
AUDITRECOTHRESHOLD=1    # THRESHOLD FOR NUMBER OF AUDIT RECORDS         		[DB]
CORUPTBLKTHRESHOLD=1    # THRESHOLD FOR NUMBER OF CORRUPTED BLOCKS			[DB]
FAILDJOBSTHRESHOLD=1    # THRESHOLD FOR NUMBER OF FAILED JOBS				[DB]
JOBSRUNSINCENDAY=1	# THRESHOLD FOR JOBS RUNNING LONGER THAN N DAY  		[DB]
NEWOBJCONTTHRESHOLD=1	# THRESHOLD FOR NUMBER OF NEWLY CREATED OBJECTS 		[DB]
MODOBJCONTTHRESHOLD=1	# THRESHOLD FOR NUMBER OF MODIFIED OBJECTS 			[DB]
LONG_RUN_QUR_HOURS=1    # THRESHOLD FOR QUERIES RUNNING LONGER THAN N HOURS             [DB]
CLUSTER_CHECK=Y		# CHECK CLUSTERWARE HEALTH					[OS]
CHKAUDITRECORDS=Y	# CHECK DATABASE AUDIT RECORDS [increases CPU Load]		[DB]
SHOWSQLTUNINGADVISOR=N	# SHOW SQL TUNING ADVISOR RESULTS IN THE REPORT			[DB]
SHOWMEMORYADVISORS=N	# SHOW MEMORY ADVISORS RESULTS IN THE REPORT                 	[DB]
SHOWSEGMENTADVVISOR=N	# SHOW SEGMENT ADVISOR RESULTS IN THE REPORT                 	[DB]
SHOWJOBS=Y		# SHOW DB JOBS DETAILS IN THE REPORT				[DB]
SHOWHASHEDCRED=Y	# SHOW DB USERS HASHED VERSION CREDENTIALS IN THE REPORT	[DB]

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances dbalarm will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM"           #Excluding INSTANCES [Will get excluded from the report].

# #########################
# Excluded ERRORS:
# #########################
# Here you can exclude the errors that you don't want to be alerted when they appear in the logs:
# Use pipe "|" between each error.

EXL_ALERT_ERR="ORA-2396|TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"              #Excluded ALERTLOG ERRORS [Will not get reported].
EXL_LSNR_ERR="TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"                        #Excluded LISTENER ERRORS [Will not get reported].


# ################################
# Excluded FILESYSTEM/MOUNT POINTS:
# ################################
# Here you can exclude specific filesystems/mount points from being reported by dbalarm:
# e.g. Excluding: /dev/mapper, /dev/asm mount points:

EXL_FS="\/dev\/mapper\/|\/dev\/asm\/"                                                   #Excluded mount points [Will be skipped during the check].

# Workaround df command output bug "`/root/.gvfs': Permission denied"
if [ -f /etc/redhat-release ]
 then
  export DF='df -hPx fuse.gvfs-fuse-daemon'
 else
  export DF='df -h'
fi

# #########################
# Checking The FILESYSTEM:
# #########################

# Report Partitions that reach the threshold of Used Space:

FSLOG=/tmp/filesystem_DBA_BUNDLE.log
echo "[Reported By ${SCRIPT_NAME} Script]"       > ${FSLOG}
echo ""                                         >> ${FSLOG}
${DF}                                           >> ${FSLOG}
${DF} | grep -v "^Filesystem" |awk '{print substr($0, index($0, $2))}'| egrep -v "${EXL_FS}"|awk '{print $(NF-1)" "$NF}'| while read OUTPUT
   do
        PRCUSED=`echo ${OUTPUT}|awk '{print $1}'|cut -d'%' -f1`
        FILESYS=`echo ${OUTPUT}|awk '{print $2}'`
                if [ ${PRCUSED} -ge ${FSTHRESHOLD} ]
                 then
mail -s "ALARM: Filesystem [${FILESYS}] on Server [${SRV_NAME}] has reached ${PRCUSED}% of USED space" ${MAIL_LIST} < ${FSLOG}
                fi
   done

rm -f ${FSLOG}


# #############################
# Checking The CPU Utilization:
# #############################

# Report CPU Utilization if reach >= CPUTHRESHOLD:
OS_TYPE=`uname -s`
CPUUTLLOG=/tmp/CPULOG_DBA_BUNDLE.log

# Getting CPU utilization in last 5 seconds:
case `uname` in
        Linux ) CPU_REPORT_SECTIONS=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1 | grep ';' -o | wc -l`
		CPU_COUNT=`cat /proc/cpuinfo|grep processor|wc -l`
                        if [ ${CPU_REPORT_SECTIONS} -ge 6 ]; then
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 7`
                        else
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 6`
                        fi
        ;;
        AIX )   CPU_IDLE=`iostat -t $INTERVAL_SEC $NUM_REPORT | sed -e 's/,/./g'|tr -s ' ' ';' | tail -1 | cut -d ";" -f 6`
		CPU_COUNT=`lsdev -C|grep Process|wc -l`
        ;;
        SunOS ) CPU_IDLE=`iostat -c $INTERVAL_SEC $NUM_REPORT | tail -1 | awk '{ print $4 }'`
		CPU_COUNT=`psrinfo -v|grep "Status of processor"|wc -l`
        ;;
        HP-UX) 	SAR="/usr/bin/sar"
		CPU_COUNT=`lsdev -C|grep Process|wc -l`
                if [ ! -x $SAR ]; then
                 echo "sar command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
                else
                 CPU_IDLE=`/usr/bin/sar 1 5 | grep Average | awk '{ print $5 }'`
                fi
        ;;
        *) echo "uname command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
        ;;
        esac

# Getting Utilized CPU (100-%IDLE):
CPU_UTL_FLOAT=`echo "scale=2; 100-($CPU_IDLE)"|bc`

# Convert the average from float number to integer:
CPU_UTL=${CPU_UTL_FLOAT%.*}

	if [ -z ${CPU_UTL} ]
	 then
	  CPU_UTL=1
	fi

# Compare the current CPU utilization with the Threshold:
CPULOG=/tmp/top_processes_DBA_BUNDLE.log

        if [ ${CPU_UTL} -ge ${CPUTHRESHOLD} ]
	 then
                export COLUMNS=300           #Increase the COLUMNS width to display the full output [Default is 167]
		echo "CPU STATS:"	  >  ${CPULOG}
                echo "========="   	  >> ${CPULOG}
		mpstat 1 5		  >> ${CPULOG}
		echo ""			  >> ${CPULOG}
                echo "VMSTAT Output:"     >> ${CPULOG}
                echo "============="   	  >> ${CPULOG}
		echo "[If the runqueue number in the (r) column exceeds the number of CPUs [${CPU_COUNT}] this indicates a CPU bottleneck on the system]." >> ${CPULOG}
                echo ""                   >> ${CPULOG}
		vmstat 2 5		  >> ${CPULOG}
                echo ""                   >> ${CPULOG}
		echo "Top 10 Processes:"  >> ${CPULOG}
		echo "================"   >> ${CPULOG}
		echo "" 		  >> ${CPULOG}
		top -c -b -n 1|head -17   >> ${CPULOG}
                unset COLUMNS                #Set COLUMNS width back to the default value
		#ps -eo pcpu,pid,user,args | sort -k 1 -r | head -11 >> ${CPULOG}
# Check ACTIVE SESSIONS on DB side:
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# Getting ORACLE_HOME:
# ###################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from PWDX is ${ORACLE_HOME}"

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from orapipe search is ${ORACLE_HOME}"
fi


# Check Long Running Transactions if CPUDIGMORE=Y:
                 case ${CPUDIGMORE} in
                 y|Y|yes|YES|Yes|ON|On|on)
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize ${SQLLINESIZE}
SPOOL ${CPULOG} APPEND
prompt
prompt ----------------------------------------------------------------

Prompt ACTIVE SESSIONS ON DATABASE ${ORACLE_SID}:
prompt ----------------------------------------------------------------

set feedback off linesize ${SQLLINESIZE} pages 1000
col "OS_PID" for a8
col module for a30
col event for a27
col "USER|SID,SER# |MOD|MACHINE" for a60
col WAIT_STATE for a25
col "STATUS|WAIT_STATE|TIME_WAITED" for a31
col "CURR_SQLID" for a35
col "SQLID | FULL_SQL_TEXT" for a75
select p.spid "OS_PID",s.USERNAME||'|'||s.sid||','||s.serial#||' | '||substr(s.MODULE,1,27)||'|'||substr(s.MACHINE,1,20) "USER|SID,SER# |MOD|MACHINE",
substr(s.status||'|'||w.state||'|'||w.seconds_in_wait||'|'||LAST_CALL_ET||'|'||LOGON_TIME,1,50) "ST|WA_ST|WAITD|ACTIVE|LOGIN",
substr(s.status||'|'||w.state||'|'||w.seconds_in_wait||'sec',1,30) "STATUS|WAIT_STATE|TIME_WAITED",
--substr(w.event,1,30)"EVENT",s.SQL_ID ||' | '|| Q.SQL_FULLTEXT "SQLID | FULL_SQL_TEXT"
substr(w.event,1,30)"EVENT",s.SQL_ID
from v\$session s,v\$process p, v\$session_wait w, v\$SQL Q
where s.username is not null
and s.status='ACTIVE'
and p.addr = s.paddr
and s.sid=w.sid
and s.SQL_ID=Q.SQL_ID
order by s.USERNAME||' | '||s.sid||','||s.serial#,s.MODULE;

prompt
prompt ----------------------------------------------------------------

Prompt Long Running Operations On DATABASE ${ORACLE_SID}:
prompt ----------------------------------------------------------------

col "USER | SID,SERIAL#" for a40
col MESSAGE for a80
col "%COMPLETE" for 999.99
col "SID|SERIAL#" for a12
	set linesize ${SQLLINESIZE}
	select USERNAME||' | '||SID||','||SERIAL# "USER | SID,SERIAL#",SQL_ID,START_TIME,SOFAR/TOTALWORK*100 "%COMPLETE",
	trunc(ELAPSED_SECONDS/60) MIN_ELAPSED, trunc(TIME_REMAINING/60) MIN_REMAINING,substr(MESSAGE,1,80)MESSAGE
	from v\$session_longops where SOFAR/TOTALWORK*100 <>'100'
	order by MIN_REMAINING;

SPOOL OFF
EOF

		;;
		esac
  done
mail -s "ALERT: CPU Utilization on Server [${SRV_NAME}] has reached [${CPU_UTL}%]" ${MAIL_LIST} < ${CPULOG}
	fi

rm -f ${CPUUTLLOG}
rm -f ${CPULOG}

# #########################
# Getting ORACLE_SID:
# #########################
# Exit with sending Alert mail if No DBs are running:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
	if [ $INS_COUNT -eq 0 ]
	 then
	 echo "[Reported By ${SCRIPT_NAME} Script]" 						 > /tmp/oracle_processes_DBA_BUNDLE.log
	 echo " " 										>> /tmp/oracle_processes_DBA_BUNDLE.log
	 echo "Current running INSTANCES on server [${SRV_NAME}]:" 				>> /tmp/oracle_processes_DBA_BUNDLE.log
	 echo "***************************************************"				>> /tmp/oracle_processes_DBA_BUNDLE.log
	 ps -ef|grep -v grep|grep pmon 								>> /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Current running LISTENERS on server [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                        	>> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep tnslsnr                                                       >> /tmp/oracle_processes_DBA_BUNDLE.log
mail -s "ALARM: No Databases Are Running on Server ${SRV_NAME} !!!" ${MAIL_LIST} 		 < /tmp/oracle_processes_DBA_BUNDLE.log
	 rm -f /tmp/oracle_processes_DBA_BUNDLE.log
 	 exit
	fi

# #########################
# Setting ORACLE_SID:
# #########################
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
  PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
  export PMON_PID
  ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from PWDX is ${ORACLE_HOME}"

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from orapipe search is ${ORACLE_HOME}"
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
mail -s "dbalarm script on Server [${SRV_NAME}] failed to find ORACLE_HOME, Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory" ${MAIL_LIST} < /dev/null
exit
fi


# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin
export LOG_DIR=${USR_ORA_HOME}/BUNDLE_Logs
mkdir -p ${LOG_DIR}
chown -R ${ORA_USER} ${LOG_DIR}
chmod -R go-rwx ${LOG_DIR}

        if [ ! -d ${LOG_DIR} ]
         then
          mkdir -p /tmp/BUNDLE_Logs
          export LOG_DIR=/tmp/BUNDLE_Logs
          chown -R ${ORA_USER} ${LOG_DIR}
          chmod -R go-rwx ${LOG_DIR}
        fi

# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ########################
# Getting ORACLE_BASE:
# ########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
  ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' $USR_ORA_HOME/.bash* $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
fi

# #########################
# Getting DB_NAME:
# #########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT name from v\$database
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo ${VAL1}| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "${DB_NAME_UPPER}" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME is Uppercase or Lowercase?:

     if [ -d ${ORACLE_HOME}/diagnostics/${DB_NAME_LOWER} ]
        then
                DB_NAME=${DB_NAME_LOWER}
        else
                DB_NAME=${DB_NAME_UPPER}
     fi

# #########################
# Getting DB_UNQ_NAME:
# #########################
VAL121=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_unique_name';
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_UNQ_NAME=`echo $VAL121| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export DB_UNQ_NAME

# In case DB_UNQ_NAME variable is empty then use DB_NAME instead:
case ${DB_UNQ_NAME}
	in '') DB_UNQ_NAME=${DB_NAME}; export DB_UNQ_NAME;;
esac

# ###################
# Checking DB Version:
# ###################

VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo $VAL311|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB Block Size:
# #####################
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB ROLE:
# #####################
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select DATABASE_ROLE from v\$database;
exit;
EOF
)
DB_ROLE=`echo $VAL312|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${DB_ROLE} in
         PRIMARY) DB_ROLE_ID=0;;
               *) DB_ROLE_ID=1;;
        esac


# ############################################
# Checking LONG RUNNING DB JOBS:
# ############################################
VAL410=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
--SELECT count(*) from dba_scheduler_running_jobs where extract(day FROM elapsed_time) > ${JOBSRUNSINCENDAY} and SESSION_ID is not null;
SELECT count(*) from dba_scheduler_running_jobs where extract(day FROM elapsed_time) > ${JOBSRUNSINCENDAY};
exit;
EOF
)
VAL510=`echo ${VAL410} | awk '{print $NF}'`
                if [ ${VAL510} -ge 1 ]
                 then
VAL610=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
spool ${LOG_DIR}/long_running_jobs.log
PROMPT Long Running Jobs:
PROMPT ^^^^^^^^^^^^^^^^^

col INS for 999
col "JOB_NAME|OWNER|SPID|SID" for a55
col ELAPSED_TIME for a17
col CPU_USED for a17
col "WAIT_SEC"  for 9999999999
col WAIT_CLASS for a15
col "BLKD_BY" for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
and     extract(day FROM elapsed_time) > ${JOBSRUNSINCENDAY}
order by "JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

spool off
exit;
EOF
)

mail -s "WARNING: JOBS running for more than ${JOBSRUNSINCENDAY} day detected on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${LOG_DIR}/long_running_jobs.log
rm -f ${LOG_DIR}/long_running_jobs.log
                fi

# ############################################
# Checking FAILED JOBS ON THE DATABASE:
# ############################################
VAL40=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
--SELECT (SELECT COUNT(*) FROM dba_jobs where failures <> '0') + (SELECT COUNT(*) FROM dba_scheduler_jobs where FAILURE_COUNT <> '0') FAIL_COUNT FROM dual;
SELECT (SELECT COUNT(*) FROM dba_jobs where failures <> '0') + (SELECT COUNT(*) FROM DBA_SCHEDULER_JOB_RUN_DETAILS where LOG_DATE > sysdate-1 and STATUS<>'SUCCEEDED') FAIL_COUNT FROM dual;
exit;
EOF
)
VAL50=`echo ${VAL40} | awk '{print $NF}'`
                if [ ${VAL50} -ge ${FAILDJOBSTHRESHOLD} ]
                 then
VAL60=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
spool ${LOG_DIR}/failed_jobs.log
PROMPT DBMS_JOBS:
PROMPT ^^^^^^^^^^

col LAST_RUN for a25
col NEXT_RUN for a25
set long 9999999
--select dbms_xmlgen.getxml('select job,schema_user,failures,LAST_DATE LAST_RUN,NEXT_DATE NEXT_RUN from dba_jobs where failures <> 0') xml from dual;
select job,schema_user,failures,to_char(LAST_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN from dba_jobs where failures <> '0';

PROMPT 
PROMPT DBMS_SCHEDULER:
PROMPT ^^^^^^^^^^^^^^^

col OWNER for a25
col JOB_NAME for a40
col STATE for a11
col STATUS for a11
col FAILURE_COUNT for 999 heading 'Fail'
col RUNTIME_IN_LAST24H for a25
col RUN_DURATION for a14
--HTML format Outputs:
--Set Markup Html On Entmap On Spool On Preformat Off
-- Get the whole failed runs in the last 24 hours:
select to_char(LOG_DATE,'DD-Mon-YYYY hh24:mi:ss')RUNTIME_IN_LAST24H,OWNER,JOB_NAME,STATUS,ERROR#,RUN_DURATION from DBA_SCHEDULER_JOB_RUN_DETAILS where LOG_DATE > sysdate-1 and STATUS<>'SUCCEEDED';

--XML Output
--select dbms_xmlgen.getxml('select to_char(LOG_DATE,''DD-Mon-YYYY hh24:mi:ss'')RUNTIME_IN_LAST24H,OWNER,JOB_NAME,STATUS,ERROR#,RUN_DURATION from DBA_SCHEDULER_JOB_RUN_DETAILS where LOG_DATE > sysdate-1 and STATUS<>''SUCCEEDED''') xml from dual;


spool off
exit;
EOF
)
mail -s "WARNING: FAILED JOBS detected on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${LOG_DIR}/failed_jobs.log
rm -f ${LOG_DIR}/failed_jobs.log
                fi

# ############################################
# LOGFILE SETTINGS:
# ############################################

# Logfile path variable:
DB_HEALTHCHK_RPT=${LOG_DIR}/${DB_NAME}_HEALTH_CHECK_REPORT.log
export DB_HEALTHCHK_RPT

# Flush the logfile:
echo "^^^^^^^^^^^"                       > ${DB_HEALTHCHK_RPT}
echo "REPORTED BY: ${SCRIPT_NAME}"      >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^"                      >> ${DB_HEALTHCHK_RPT}
echo ""                                 >> ${DB_HEALTHCHK_RPT}

# ############################################
# Checking RAC/ORACLE_RESTART Services:
# ############################################

		case ${CLUSTER_CHECK} in
                y|Y|yes|YES|Yes|ON|On|on)

# Check for ocssd clusterware process:
CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
CHECK_CRSD=`ps -ef|grep 'crsd.bin'|grep -v grep|wc -l`

if [ ${CHECK_CRSD} -gt 0 ]
then
 CLS_STR=crs
 export CLS_STR
 CLUSTER_TYPE=CLUSTERWARE
 export CLUSTER_TYPE
else
 CLS_STR=has
 export CLS_STR
 CLUSTER_TYPE=ORACLE_RESTART
 export CLUSTER_TYPE
fi

	if [ ${CHECK_CRSD} -gt 0 ]
	 then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME

echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${DB_HEALTHCHK_RPT}
echo "CLUSTERWARE CHECKS:"                                              >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}

FILE_NAME=${GRID_HOME}/bin/ocrcheck
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${DB_HEALTHCHK_RPT}
echo "OCR DISKS CHECKING:"                                              >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^"                                              >> ${DB_HEALTHCHK_RPT}
${GRID_HOME}/bin/ocrcheck                                               >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
fi

FILE_NAME=${GRID_HOME}/bin/crsctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^"                                             >> ${DB_HEALTHCHK_RPT}
echo "VOTE DISKS CHECKING:"                                             >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^"                                             >> ${DB_HEALTHCHK_RPT}
${GRID_HOME}/bin/crsctl query css votedisk                              >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
fi
	fi

	if [ ${CHECK_OCSSD} -gt 0 ]
	 then

GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"`
export GRID_HOME

FILE_NAME=${GRID_HOME}/bin/crsctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^^^^"                                          >> ${DB_HEALTHCHK_RPT}
echo "${CLUSTER_TYPE} SERVICES:"                                        >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^^^^"                                          >> ${DB_HEALTHCHK_RPT}
AWK=/usr/bin/awk 
$AWK \
'BEGIN {printf "%-55s %-24s %-18s\n", "HA Resource", "Target", "State";
printf "%-55s %-24s %-18s\n", "-----------", "------", "-----";}'	>> ${DB_HEALTHCHK_RPT}
$GRID_HOME/bin/crsctl status resource | $AWK \
'BEGIN { FS="="; state = 0; }
$1~/NAME/ && $2~/'$1'/ {appname = $2; state=1};
state == 0 {next;}
$1~/TARGET/ && state == 1 {apptarget = $2; state=2;}
$1~/STATE/ && state == 2 {appstate = $2; state=3;}
state == 3 {printf "%-55s %-24s %-18s\n", appname, apptarget, appstate; state=0;}'	>> ${DB_HEALTHCHK_RPT}
fi 

FILE_NAME=${ORACLE_HOME}/bin/srvctl
export FILE_NAME
if [ -f ${FILE_NAME} ]
then
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^^^^^"                                         >> ${DB_HEALTHCHK_RPT}
echo "DATABASE SERVICES STATUS:"                                        >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^^^^^^^^^^^"                                         >> ${DB_HEALTHCHK_RPT}
${ORACLE_HOME}/bin/srvctl status service -d ${DB_UNQ_NAME}              >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
fi

	fi
		;;
		esac

echo ""                                                                 >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^"                                                   >> ${DB_HEALTHCHK_RPT}
echo "Local Filesystem:"                                                >> ${DB_HEALTHCHK_RPT}
echo "^^^^^^^^^^^^^^"                                                   >> ${DB_HEALTHCHK_RPT}
${DF}                                                                   >> ${DB_HEALTHCHK_RPT}
echo ""                                                                 >> ${DB_HEALTHCHK_RPT}


# ############################################
# Checking Advisors:
# ############################################
# Checking if the Advisors should be enabled in the report:

        case ${SHOWSQLTUNINGADVISOR} in
        Y|y|YES|Yes|yes|ON|On|on)
	export HASHSTA="";;
	*)
	export HASHSTA="--";;
	esac

        case ${SHOWMEMORYADVISORS} in
        Y|y|YES|Yes|yes|ON|On|on)
	export HASHMA="";;
	*)
	export HASHMA="--";;
	esac

        case ${SHOWSEGMENTADVVISOR} in
        Y|y|YES|Yes|yes|ON|On|on)
	export HASHSA="";;
	*)
	export HASHSA="--";;
	esac

        case ${SHOWJOBS} in
        Y|y|YES|Yes|yes|ON|On|on)
	export HASHJ="";;
	*)
	export HASHJ="--";;
	esac


	case ${SHOWHASHEDCRED} in
        Y|y|YES|Yes|yes|ON|On|on)
        export HASHCRD="";;
        *)
        export HASHCRD="--";;
        esac


# If the database version is 10g onward collect the advisors recommendations:
        if [ ${DB_VER} -gt 9 ]
         then

VAL611=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 100
spool ${DB_HEALTHCHK_RPT} app

PROMPT
PROMPT ^^^^^^^^^^^^^^

PROMPT Tablespaces Size:  [Based on Datafiles MAXSIZE]
PROMPT ^^^^^^^^^^^^^^

set pages 1000 linesize ${SQLLINESIZE} tab off
col tablespace_name for A25
col Total_MB for 999999999999
col Used_MB for 999999999999
col '%Used' for 999.99
comp sum of Total_MB on report
comp sum of Used_MB   on report
bre on report
select tablespace_name,
       (tablespace_size*$blksize)/(1024*1024) Total_MB,
       (used_space*$blksize)/(1024*1024) Used_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;


PROMPT ^^^^^^^^^^^^^^

PROMPT ASM STATISTICS:
PROMPT ^^^^^^^^^^^^^^

select name,state,OFFLINE_DISKS,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;

PROMPT ^^^^^^^^^^^^^^

PROMPT FRA STATISTICS:
PROMPT ^^^^^^^^^^^^^^

PROMPT
PROMPT FRA_SIZE:
PROMPT ^^^^^^^^^

col name for a35
SELECT NAME,NUMBER_OF_FILES,SPACE_LIMIT/1024/1024/1024 AS TOTAL_SIZE_GB,SPACE_USED/1024/1024/1024 SPACE_USED_GB,
SPACE_RECLAIMABLE/1024/1024/1024 SPACE_RECLAIMABLE_GB,ROUND((SPACE_USED-SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL_AFTER_CLAIM",
ROUND((SPACE_USED)/SPACE_LIMIT * 100, 1) AS "%FULL_NOW" FROM V\$RECOVERY_FILE_DEST;

PROMPT FRA_COMPONENTS:
PROMPT ^^^^^^^^^^^^^^^^^

select * from v\$flash_recovery_area_usage;

PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT DATABASE GROWTH: [In the Last ~8 days]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
set serveroutput on
Declare 
    v_BaselineSize    number(20); 
    v_CurrentSize    number(20); 
    v_TotalGrowth    number(20); 
    v_Space        number(20); 
    cursor usageHist is 
            select a.snap_id, 
            SNAP_TIME, 
            sum(TOTAL_SPACE_ALLOCATED_DELTA) over ( order by a.SNAP_ID) ProgSum 
        from 
            (select SNAP_ID, 
                sum(SPACE_ALLOCATED_DELTA) TOTAL_SPACE_ALLOCATED_DELTA 
            from DBA_HIST_SEG_STAT 
            group by SNAP_ID 
            having sum(SPACE_ALLOCATED_TOTAL) <> 0 
            order by 1 ) a, 
            (select distinct SNAP_ID, 
                to_char(END_INTERVAL_TIME,'DD-Mon-YYYY HH24:Mi') SNAP_TIME 
            from DBA_HIST_SNAPSHOT) b 
        where a.snap_id=b.snap_id; 
Begin 
    select sum(SPACE_ALLOCATED_DELTA) into v_TotalGrowth from DBA_HIST_SEG_STAT; 
    select sum(bytes) into v_CurrentSize from dba_segments; 
    v_BaselineSize := (v_CurrentSize - v_TotalGrowth) ;
    dbms_output.put_line('SNAP_TIME           Database Size(GB)');
    for row in usageHist loop 
            v_Space := (v_BaselineSize + row.ProgSum)/(1024*1024*1024); 
        dbms_output.put_line(row.SNAP_TIME || '           ' || to_char(v_Space) ); 
    end loop; 
end;
/


PROMPT
PROMPT ^^^^^^^^^^^^^^^^^

PROMPT Active Incidents:
PROMPT ^^^^^^^^^^^^^^^^^

set linesize ${SQLLINESIZE}
col RECENT_PROBLEMS_1_WEEK_BACK for a45
select PROBLEM_KEY RECENT_PROBLEMS_1_WEEK_BACK,to_char(FIRSTINC_TIME,'DD-MON-YY HH24:mi:ss') FIRST_OCCURENCE,to_char(LASTINC_TIME,'DD-MON-YY HH24:mi:ss')
LAST_OCCURENCE FROM V\$DIAG_PROBLEM WHERE LASTINC_TIME > SYSDATE -10;
PROMPT
PROMPT OUTSTANDING ALERTS:
PROMPT ^^^^^^^^^^^^^^^^^^^

select * from DBA_OUTSTANDING_ALERTS;

PROMPT
PROMPT CORRUPTED BLOCKS:
PROMPT ^^^^^^^^^^^^^^^^^

select * from V\$DATABASE_BLOCK_CORRUPTION;

PROMPT
PROMPT BLOCKING SESSIONS:
PROMPT ^^^^^^^^^^^^^^^^^^

set linesize ${SQLLINESIZE} pages 0 echo on feedback on
col BLOCKING_STATUS for a90
select 'User: '||s1.username || '@' || s1.machine || '(SID=' || s1.sid ||' ) running SQL_ID:'||s1.sql_id||' is blocking
User: '|| s2.username || '@' || s2.machine || '(SID=' || s2.sid || ') running SQL_ID:'||s2.sql_id||' For '||s2.SECONDS_IN_WAIT||' sec
----------------------------------------------------------------
Warn user '||s1.username||' Or use the following statement to kill his session:
----------------------------------------------------------------
ALTER SYSTEM KILL SESSION '''||s1.sid||','||s1.serial#||''' immediate;' AS blocking_status
from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
 where s1.sid=l1.sid and s2.sid=l2.sid 
 and l1.BLOCK=1 and l2.request > 0
 and l1.id1 = l2.id1
 and l2.id2 = l2.id2
 order by s2.SECONDS_IN_WAIT desc;

PROMPT
PROMPT UN-USABLE INDEXES:
PROMPT ^^^^^^^^^^^^^^^^^^
                
PROMPT            
set echo on feedback on pages 1000
select 'ALTER INDEX '||OWNER||'.'||INDEX_NAME||' REBUILD ONLINE;' from dba_indexes where status='UNUSABLE';

PROMPT
PROMPT INVALID OBJECTS:
PROMPT ^^^^^^^^^^^^^^^

PROMPT
set pages 0
select 'alter package '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type like '%PACKAGE%' union
select 'alter type '||owner||'.'||object_name||' compile specification;' from dba_objects where status <> 'VALID' and object_type like '%TYPE%'union
select 'alter '||object_type||' '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type not in ('PACKAGE','PACKAGE BODY','SYNONYM','TYPE','TYPE BODY') union
select 'alter public synonym '||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type ='SYNONYM';
set pages 1000

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT RMAN BACKUP OPERATIONS: [LAST 24H]
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^

col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display ,COMPRESSION_RATIO
FROM v\$rman_backup_job_details
WHERE end_time > sysdate -1;

${HASHJ}PROMPT
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^^^^^^^

${HASHJ}PROMPT SCHEDULED JOBS STATUS:
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^^^^^^^

${HASHJ}PROMPT
${HASHJ}PROMPT DBMS_JOBS:
${HASHJ}PROMPT ^^^^^^^^^^

${HASHJ}set linesize ${SQLLINESIZE}
${HASHJ}col LAST_RUN for a25
${HASHJ}col NEXT_RUN for a25
${HASHJ}select job,schema_user,failures,to_char(LAST_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN from dba_jobs;

${HASHJ}PROMPT 
${HASHJ}PROMPT DBMS_SCHEDULER:
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^

${HASHJ}col OWNER for a15
${HASHJ}col STATE for a15
${HASHJ}col FAILURE_COUNT for 9999 heading 'Fail'
${HASHJ}col "DURATION(d:hh:mm:ss)" for a22
${HASHJ}col REPEAT_INTERVAL for a70
${HASHJ}col "LAST_RUN || REPEAT_INTERVAL" for a65
${HASHJ}col "DURATION(d:hh:mm:ss)" for a12
${HASHJ}select JOB_NAME,OWNER,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss')||' || '||REPEAT_INTERVAL "LAST_RUN || REPEAT_INTERVAL",
${HASHJ}extract(day from last_run_duration) ||':'||
${HASHJ}lpad(extract(hour from last_run_duration),2,'0')||':'||
${HASHJ}lpad(extract(minute from last_run_duration),2,'0')||':'||
${HASHJ}lpad(round(extract(second from last_run_duration)),2,'0') "DURATION(d:hh:mm:ss)"
${HASHJ}from dba_scheduler_jobs order by ENABLED,STATE;

${HASHJ}PROMPT 
${HASHJ}PROMPT Current Running Jobs:
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^^^^
${HASHJ}col INS				for 999
${HASHJ}col "JOB_NAME|OWNER|SPID|SID"	for a55
${HASHJ}col ELAPSED_TIME		for a17
${HASHJ}col CPU_USED 			for a17
${HASHJ}col "WAIT_SEC"  		for 9999999999
${HASHJ}col WAIT_CLASS 			for a15
${HASHJ}col "BLKD_BY" 			for 9999999
${HASHJ}col "WAITED|WCLASS|EVENT" 	for a45
${HASHJ}select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
${HASHJ},s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
${HASHJ},substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
${HASHJ}from dba_scheduler_running_jobs j, gv\$session s
${HASHJ}where   j.RUNNING_INSTANCE=S.INST_ID(+)
${HASHJ}and     j.SESSION_ID=S.SID(+)
${HASHJ}order by "JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

${HASHJ}PROMPT
${HASHJ}PROMPT AUTOTASK INTERNAL MAINTENANCE WINDOWS:
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHJ}col WINDOW_NAME for a17
${HASHJ}col NEXT_RUN for a20
${HASHJ}col ACTIVE for a6
${HASHJ}col OPTIMIZER_STATS for a15
${HASHJ}col SEGMENT_ADVISOR for a15
${HASHJ}col SQL_TUNE_ADVISOR for a16
${HASHJ}col HEALTH_MONITOR for a15
${HASHJ}SELECT WINDOW_NAME,TO_CHAR(WINDOW_NEXT_TIME,'DD-MM-YYYY HH24:MI:SS') NEXT_RUN,AUTOTASK_STATUS STATUS,WINDOW_ACTIVE ACTIVE,OPTIMIZER_STATS,SEGMENT_ADVISOR,SQL_TUNE_ADVISOR,HEALTH_MONITOR FROM DBA_AUTOTASK_WINDOW_CLIENTS;

${HASHJ}PROMPT
${HASHJ}PROMPT FAILED DBMS_SCHEDULER JOBS IN THE LAST 24H:
${HASHJ}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHJ}col LOG_DATE for a36
${HASHJ}col OWNER for a15
${HASHJ}col JOB_NAME for a35
${HASHJ}col STATUS for a11
${HASHJ}col RUN_DURATION for a20
${HASHJ}col ID for 99
${HASHJ}select INSTANCE_ID ID,JOB_NAME,OWNER,LOG_DATE,STATUS,ERROR#,RUN_DURATION from DBA_SCHEDULER_JOB_RUN_DETAILS where LOG_DATE > sysdate-1 and STATUS='FAILED' order by JOB_NAME,LOG_DATE;


PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT Queries Running For More Than [${LONG_RUN_QUR_HOURS}] Hours:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col module for a30
col DURATION_HOURS for 99999.9
col STARTED_AT for a13
col "USERNAME| SID,SERIAL#" for a30
col "SQL_ID | SQL_TEXT" for a120
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
--||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
,SQL_ID
from v\$session where
username is not null 
and module is not null
and last_call_et > 60*60*${LONG_RUN_QUR_HOURS}
and status = 'ACTIVE';


PROMPT ^^^^^^^^^^^^^^^^

PROMPT ADVISORS STATUS:
PROMPT ^^^^^^^^^^^^^^^^

col CLIENT_NAME for a60
col window_group for a60
col STATUS for a15
SELECT client_name, status, consumer_group, window_group FROM dba_autotask_client ORDER BY client_name;

${HASHSTA}PROMPT
${HASHSTA}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHSTA}PROMPT SQL TUNING ADVISOR:
${HASHSTA}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHSTA}PROMPT
${HASHSTA}PROMPT Last Execution of SQL TUNING ADVISOR:
${HASHSTA}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHSTA}col TASK_NAME for a60
${HASHSTA}set long 2000000000
${HASHSTA}SELECT task_name, status, TO_CHAR(execution_end,'DD-MON-YY HH24:MI') Last_Execution FROM dba_advisor_executions where TASK_NAME='SYS_AUTO_SQL_TUNING_TASK' and execution_end>sysdate-1;


${HASHSTA}variable Findings_Report CLOB;
${HASHSTA}	BEGIN
${HASHSTA}	:Findings_Report :=DBMS_SQLTUNE.REPORT_AUTO_TUNING_TASK(
${HASHSTA}	begin_exec => NULL,
${HASHSTA}	end_exec => NULL,
${HASHSTA}	type => 'TEXT',
${HASHSTA}	level => 'TYPICAL',
${HASHSTA}	section => 'ALL',
${HASHSTA}	object_id => NULL,
${HASHSTA}	result_limit => NULL);
${HASHSTA}	END;
${HASHSTA}	/
${HASHSTA}	print :Findings_Report

${HASHMA}PROMPT
${HASHMA}PROMPT
${HASHMA}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHMA}PROMPT MEMORY ADVISORS:
${HASHMA}PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

${HASHMA}PROMPT
${HASHMA}PROMPT SGA ADVISOR:
${HASHMA}PROMPT ^^^^^^^^^^^^

${HASHMA}col ESTD_DB_TIME for 99999999999999999
${HASHMA}col ESTD_DB_TIME_FACTOR for 9999999999999999999999999999
${HASHMA}select * from V\$SGA_TARGET_ADVICE where SGA_SIZE_FACTOR > .6 and SGA_SIZE_FACTOR < 1.6;

${HASHMA}PROMPT
${HASHMA}PROMPT Buffer Cache ADVISOR:
${HASHMA}PROMPT ^^^^^^^^^^^^^^^^^^^^^

${HASHMA}col ESTD_SIZE_MB for 9999999999999
${HASHMA}col ESTD_PHYSICAL_READS for 99999999999999999999
${HASHMA}col ESTD_PHYSICAL_READ_TIME for 99999999999999999999
${HASHMA}select SIZE_FACTOR "%SIZE",SIZE_FOR_ESTIMATE ESTD_SIZE_MB,ESTD_PHYSICAL_READS,ESTD_PHYSICAL_READ_TIME,ESTD_PCT_OF_DB_TIME_FOR_READS
${HASHMA}from V\$DB_CACHE_ADVICE where SIZE_FACTOR >.8 and SIZE_FACTOR<1.3;

${HASHMA}PROMPT
${HASHMA}PROMPT Shared Pool ADVISOR:
${HASHMA}PROMPT ^^^^^^^^^^^^^^^^^^^^^

${HASHMA}col SIZE_MB for 99999999999
${HASHMA}col SIZE_FACTOR for 99999999
${HASHMA}col ESTD_SIZE_MB for 99999999999999999999
${HASHMA}col LIB_CACHE_SAVED_TIME for 99999999999999999999999999
${HASHMA}select SHARED_POOL_SIZE_FOR_ESTIMATE SIZE_MB,SHARED_POOL_SIZE_FACTOR "%SIZE",SHARED_POOL_SIZE_FOR_ESTIMATE/1024/1024 ESTD_SIZE_MB,ESTD_LC_TIME_SAVED LIB_CACHE_SAVED_TIME,
${HASHMA}ESTD_LC_LOAD_TIME PARSING_TIME from V\$SHARED_POOL_ADVICE
${HASHMA}where SHARED_POOL_SIZE_FACTOR > .9 and SHARED_POOL_SIZE_FACTOR  < 1.6;


${HASHMA}PROMPT
${HASHMA}PROMPT PGA ADVISOR:
${HASHMA}PROMPT ^^^^^^^^^^^^

${HASHMA}col SIZE_FACTOR  for 999999999
${HASHMA}col ESTD_SIZE_MB for 99999999999999999999
${HASHMA}col MB_PROCESSED for 99999999999999999999
${HASHMA}col ESTD_TIME for 99999999999999999999
${HASHMA}select PGA_TARGET_FACTOR "%SIZE",PGA_TARGET_FOR_ESTIMATE/1024/1024 ESTD_SIZE_MB,BYTES_PROCESSED/1024/1024 MB_PROCESSED,
${HASHMA}ESTD_TIME,ESTD_PGA_CACHE_HIT_PERCENTAGE PGA_HIT,ESTD_OVERALLOC_COUNT PGA_SHORTAGE
${HASHMA}from V\$PGA_TARGET_ADVICE where PGA_TARGET_FACTOR > .7 and PGA_TARGET_FACTOR < 1.6;

${HASHSA}PROMPT
${HASHSA}PROMPT SEGMENT ADVISOR:
${HASHSA}PROMPT ^^^^^^^^^^^^^^^^

${HASHSA}select'Task Name : ' || f.task_name || chr(10) ||
${HASHSA}'Start Run Time : ' || TO_CHAR(execution_start, 'dd-mon-yy hh24:mi') || chr (10) ||
${HASHSA}'Segment Name : ' || o.attr2 || chr(10) ||
${HASHSA}'Segment Type : ' || o.type || chr(10) ||
${HASHSA}'Partition Name : ' || o.attr3 || chr(10) ||
${HASHSA}'Message : ' || f.message || chr(10) ||
${HASHSA}'More Info : ' || f.more_info || chr(10) ||
${HASHSA}'-------------------------------------------' Advice
${HASHSA}FROM dba_advisor_findings f
${HASHSA},dba_advisor_objects o
${HASHSA},dba_advisor_executions e
${HASHSA}WHERE o.task_id = f.task_id
${HASHSA}AND o.object_id = f.object_id
${HASHSA}AND f.task_id = e.task_id
${HASHSA}AND e. execution_start > sysdate - 1
${HASHSA}AND e.advisor_name = 'Segment Advisor'
${HASHSA}ORDER BY f.task_name;


PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT CURRENT OS / HARDWARE STATISTICS:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

select stat_name,value from v\$osstat;

PROMPT
PROMPT ^^^^^^^^^^^^^^^

PROMPT RESOURCE LIMIT:
PROMPT ^^^^^^^^^^^^^^^

col INITIAL_ALLOCATION for a20
col LIMIT_VALUE for a20
select * from gv\$resource_limit order by RESOURCE_NAME;

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^

PROMPT RECYCLEBIN OBJECTS#:
PROMPT ^^^^^^^^^^^^^^^^^^^^

set feedback off
select count(*) "RECYCLED_OBJECTS#",sum(space)*$blksize/1024/1024 "TOTAL_SIZE_MB" from dba_recyclebin group by 1;
set feedback on
PROMPT
PROMPT [Note: Consider Purging DBA_RECYCLEBIN for better performance]


PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT FLASHBACK RESTORE POINTS:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^

select * from V\$RESTORE_POINT;


PROMPT
PROMPT ^^^^^^^^^^^^^^^

PROMPT HEALTH MONITOR:
PROMPT ^^^^^^^^^^^^^^^

select name,type,status,description,repair_script from V\$HM_RECOMMENDATION where time_detected > sysdate -1;

PROMPT ^^^^^^^^^^^^^^^^^^

PROMPT Monitored INDEXES:
PROMPT ^^^^^^^^^^^^^^^^^^

set linesize ${SQLLINESIZE} pages 1000
col Index_NAME for a40
col TABLE_NAME for a40
        select io.name Index_NAME, t.name TABLE_NAME,decode(bitand(i.flags, 65536),0,'NO','YES') Monitoring,
        decode(bitand(ou.flags, 1),0,'NO','YES') USED,ou.start_monitoring,ou.end_monitoring
        from sys.obj$ io,sys.obj$ t,sys.ind$ i,sys.object_usage ou where i.obj# = ou.obj# and io.obj# = ou.obj# and t.obj# = i.bo#;

--PROMPT
--PROMPT To stop monitoring USED indexes use this command:

--prompt select 'ALTER INDEX RA.'||io.name||' NOMONITORING USAGE;' from sys.obj$ io,sys.obj$ t,sys.ind$ i,sys.object_usage ou where i.obj# = ou.obj# and io.obj# = ou.obj# and t.obj# = i.bo#
--prompt and decode(bitand(i.flags, 65536),0,'NO','YES')='YES' and decode(bitand(ou.flags, 1),0,'NO','YES')='YES' order by 1
--prompt /

PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^

PROMPT REDO LOG SWITCHES:
PROMPT ^^^^^^^^^^^^^^^^^^

set linesize ${SQLLINESIZE}
col day for a11
SELECT to_char(first_time,'YYYY-MON-DD') day,
to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'9999') "00",
to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'9999') "01",
to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'9999') "02",
to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'9999') "03",
to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'9999') "04",
to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'9999') "05",
to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'9999') "06",
to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'9999') "07",
to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'9999') "08",
to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'9999') "09",
to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'9999') "10",
to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'9999') "11",
to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'9999') "12",
to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'9999') "13",
to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'9999') "14",
to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'9999') "15",
to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'9999') "16",
to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'9999') "17",
to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'9999') "18",
to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'9999') "19",
to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'9999') "20",
to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'9999') "21",
to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'9999') "22",
to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'9999') "23"
from v\$log_history where first_time > sysdate-1
GROUP by to_char(first_time,'YYYY-MON-DD') order by 1 asc;


PROMPT
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PROMPT Modified Parameters Since Instance Startup:
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

col name for a45
col VALUE for a80
col DEPRECATED for a10
select NAME,VALUE,ISDEFAULT "DEFAULT",ISDEPRECATED "DEPRECATED" from v\$parameter where ISMODIFIED = 'SYSTEM_MOD' order by 1;

${HASHCRD}PROMPT
${HASHCRD}PROMPT ^^^^^^^^^^^^

${HASHCRD}PROMPT Cred Backup:
${HASHCRD}PROMPT ^^^^^^^^^^^^

${HASHCRD}col name for a35
${HASHCRD}col "CREATE_DATE||PASS_LAST_CHANGE" for a60
${HASHCRD}select name,PASSWORD HASH,CTIME ||' || '||PTIME "CREATE_DATE||PASS_LAST_CHANGE" from user\$ where PASSWORD is not null order by 1;

spool off
exit;
EOF
)

        fi

# #################################################
# Reporting New Created Objects in the last 24Hours:
# #################################################
NEWOBJCONTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
select count(*) from dba_objects
where created > sysdate-1
and owner <> 'SYS';
exit;
EOF
)
NEWOBJCONT=`echo ${NEWOBJCONTRAW} | awk '{print $NF}'`
                if [ ${NEWOBJCONT} -ge ${NEWOBJCONTTHRESHOLD} ]
                 then
VALNEWOBJCONT=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
spool ${DB_HEALTHCHK_RPT} app
prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt New Created objects [Last 24H] ...
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt
col owner for a30
col object_name for a30
col object_type for a19
col created for a20
select object_type,owner,object_name,to_char(created, 'DD-Mon-YYYY HH24:MI:SS') CREATED from dba_objects
where created > sysdate-1
and owner <> 'SYS'
order by owner,object_type;

spool off
exit;
EOF
) 
		fi

# ###############################################
# Reporting Modified Objects in the last 24Hours:
# ###############################################
MODOBJCONTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
select count(*) from dba_objects
where LAST_DDL_TIME > sysdate-1
and owner <> 'SYS';
exit;
EOF
)
MODOBJCONT=`echo ${MODOBJCONTRAW} | awk '{print $NF}'`
                if [ ${MODOBJCONT} -ge ${MODOBJCONTTHRESHOLD} ]
                 then
VALMODOBJCONT=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
spool ${DB_HEALTHCHK_RPT} app
prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt Modified objects in the Last 24H ...
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt
col owner for a30
col object_name for a30
col object_type for a19
col LAST_DDL_TIME for a20
select object_type,owner,object_name,to_char(LAST_DDL_TIME, 'DD-Mon-YYYY HH24:MI:SS') LAST_DDL_TIME from dba_objects
where LAST_DDL_TIME > sysdate-1
and owner <> 'SYS'
order by owner,object_type;

spool off
exit;
EOF
) 
                fi

# ###############################################
# Checking AUDIT RECORDS ON THE DATABASE:
# ###############################################
# Check if Checking Audit Records is ENABLED:
	case ${CHKAUDITRECORDS} in
	Y|y|YES|Yes|yes|ON|On|on)
VAL70=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT (SELECT COUNT(*) FROM dba_audit_trail
where ACTION_NAME not like 'LOGO%' and ACTION_NAME not in ('SELECT','SET ROLE') and timestamp > SYSDATE-1)
+
(SELECT COUNT(*) FROM DBA_AUDIT_SESSION WHERE timestamp > SYSDATE-1 and returncode = 1017)
+
(SELECT COUNT(*) FROM dba_fga_audit_trail WHERE timestamp > SYSDATE-1)
+
(SELECT COUNT(*) FROM dba_objects where created > sysdate-1 and owner <> 'SYS') AUD_REC_COUNT FROM dual;
exit;
EOF
)
VAL80=`echo ${VAL70} | awk '{print $NF}'`
                if [ ${VAL80} -ge ${AUDITRECOTHRESHOLD} ]
                 then
VAL90=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
spool ${LOG_DIR}/audit_records.log
col OS_USERNAME for a20
col EXTENDED_TIMESTAMP for a36
col OWNER for a25
col OBJ_NAME for a25
col OS_USERNAME for a20
col USERNAME for a25
col USERHOST for a35
col ACTION_NAME for a25
col ACTION_OWNER_OBJECT for a55
col TERMINAL for a30
col ACTION_NAME for a20
col TIMESTAMP for a21

prompt
prompt
prompt ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt Failed Login Attempts in the last 24Hours ...
prompt ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt
select to_char (EXTENDED_TIMESTAMP,'DD-MON-YYYY HH24:MI:SS') TIMESTAMP,OS_USERNAME,USERNAME,TERMINAL,USERHOST,ACTION_NAME
from DBA_AUDIT_SESSION
where returncode = 1017
and timestamp > (sysdate -1)
order by 1;

prompt
prompt
prompt ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt Audit records in the last 24Hours AUD$...
prompt ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt
select extended_timestamp,OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
from dba_audit_trail 
where
ACTION_NAME not like 'LOGO%'
and ACTION_NAME not in ('SELECT','SET ROLE')
-- and USERNAME not in ('CRS_ADMIN','DBSNMP')
-- and OS_USERNAME not in ('workflow')
-- and OBJ_NAME not like '%TMP_%'
-- and OBJ_NAME not like 'WRKDETA%'
-- and OBJ_NAME not in ('PBCATTBL','SETUP','WRKIB','REMWORK')
and timestamp > SYSDATE-1 order by EXTENDED_TIMESTAMP;
prompt
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt Fine Grained Auditing Data ...
PROMPT ^^^^^^^^^^^^^^^^^^^^^^^^^^^

prompt
col sql_text for a70
col time for a36
col USERHOST for a21
col db_user for a15
select to_char(timestamp,'DD-MM-YYYY HH24:MI:SS') as time,db_user,userhost,sql_text,SQL_BIND
from dba_fga_audit_trail
where
timestamp > SYSDATE-1
-- and policy_name='PAYROLL_TABLE'
order by EXTENDED_TIMESTAMP;

spool off
exit;
EOF
)
cat ${LOG_DIR}/audit_records.log >>  ${DB_HEALTHCHK_RPT}
                fi
	;;
	esac
mail -s "HEALTH CHECK REPORT: For Database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${DB_HEALTHCHK_RPT}

echo "HEALTH CHECK REPORT FOR DATABASE [${DB_NAME_UPPER}] WAS SAVED TO: ${DB_HEALTHCHK_RPT}"
        done

echo ""

# #############################
# De-Neutralize login.sql file: [Bug Fix]
# #############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
