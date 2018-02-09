-- Source : https://github.com/discus/Oracle-AWR-batch-generation-script/blob/master/awrreport_batch.sql

-- Oracle AWR and AWR SQL report batch generation script 
-- 
-- This script for Oracle 11g R1/R2 Unix/Linux platform. 
-- Perferably run this file on Oracle server instead of from remote client. 
-- Ensure ADDM report is also generated at end of in AWR.

whenever sqlerror exit 1;
whenever oserror exit 1;

set timi off feedback off veri off trimspool off trimout off;
set serveroutput on size unlimited;
set linesize 200;

PROMPT --;
PROMPT -- Oracle AWR and AWR SQL report batch generation script;
PROMPT --;
PROMPT -- ***** This script always generate html format AWR reports. *****;
PROMPT --;
ACCEPT report_start_snapid PROMPT 'Enter snap_id for starting AWR report generation. [NULL] : ' DEFAULT NULL;
ACCEPT num_of_days         PROMPT 'Enter number of days for reporting period. [1] : ' DEFAULT 1;
ACCEPT comment             PROMPT 'Enter suffix for AWR reports filename. [NULL] : ' DEFAULT "";
spo awrreport_exec_batch.sql;
--
DECLARE
	CURSOR cs_dbinfo IS
		SELECT
			 d.dbid
			,i.instance_number
		FROM
			v$database d 
			CROSS JOIN v$instance i
	;
	databaseid v$database.dbid%TYPE;
	databasein v$instance.instance_number%TYPE;
	--
	CURSOR cs_snapshot_info (
		 p_dbid v$database.dbid%TYPE
		,p_dbin v$instance.instance_number%TYPE
		,p_num_of_day PLS_INTEGER
	) IS
		SELECT
			 CASE 
				WHEN 	NVL(TO_NUMBER(TO_CHAR(dhs.startup_time,'yyyymmddhh24miss')),0)
						- NVL(LAG(TO_NUMBER(TO_CHAR(dhs.startup_time,'yyyymmddhh24miss')),1) 
							OVER (
								ORDER BY 
									 db_name
									,instance_name
									,snap_id
							),0) 
						= 0
				THEN 0
				ELSE 1
			 END AS is_reboot_instance
			,dhs.snap_id
		FROM
			dba_hist_snapshot dhs 
			JOIN dba_hist_database_instance dhdi
			ON
					dhdi.dbid 				= dhs.dbid
				AND	dhdi.instance_number 	= dhs.instance_number
				AND	dhdi.startup_time		= dhs.startup_time
		WHERE
				dhs.dbid				= p_dbid
			AND	dhdi.dbid				= p_dbid
			AND	dhs.instance_number		= p_dbin
			AND	dhdi.instance_number	= p_dbin
			AND	dhs.end_interval_time >= 
				DECODE( 
					 p_num_of_day
					,0
					,TO_DATE('99990131','yyyymmdd')
					,3.14
					,dhs.end_interval_time
					,TO_DATE(
						(
							SELECT
								TO_CHAR(MAX(end_interval_time),'yyyymmdd')
							FROM
								dba_hist_snapshot
							WHERE
									instance_number = p_dbin
								AND	dbid			= p_dbid
						)
						,'yyyymmdd'
					) - (p_num_of_day-1)
				)
		ORDER BY 
			 db_name
			,instance_name
			,snap_id
	;
	--
	report_start_snap# dba_hist_snapshot.snap_id%TYPE := &&report_start_snapid;
	is_first_time boolean := true;
	begin_snap# dba_hist_snapshot.snap_id%TYPE := NULL;
	end_snap# dba_hist_snapshot.snap_id%TYPE := NULL;
	--
	C_TOPN CONSTANT PLS_INTEGER := 20;
	CURSOR cs_sqlid_info(
    	    p_dbid v$database.dbid%TYPE
	    ,p_dbin v$instance.instance_number%TYPE
	    ,p_snap_id dba_hist_sqlstat.snap_id%TYPE
	    ,p_topN PLS_INTEGER
	) IS
		SELECT
			*
		FROM
			(
				SELECT
					ss.sql_id
				FROM
					dba_hist_sqlstat ss
					JOIN dba_hist_sqltext st
					ON
							ss.dbid = st.dbid
						AND	ss.sql_id = st.sql_id
				WHERE
				    ss.dbid = p_dbid
				AND ss.instance_number = p_dbin
				AND ss.snap_id = p_snap_id
				ORDER BY
					elapsed_time_delta DESC
			)
		WHERE
			rownum <= p_topN
	;
BEGIN
	FOR dbinfo_rec IN cs_dbinfo LOOP
		databaseid := dbinfo_rec.dbid;
		databasein := dbinfo_rec.instance_number;
	END LOOP;
	--
	DBMS_OUTPUT.PUT_LINE('--');
	DBMS_OUTPUT.PUT_LINE('--');
	DBMS_OUTPUT.PUT_LINE('--');
	DBMS_OUTPUT.PUT_LINE('clear break compute;');
	DBMS_OUTPUT.PUT_LINE('repfooter off;');
	DBMS_OUTPUT.PUT_LINE('ttitle off;');
	DBMS_OUTPUT.PUT_LINE('btitle off;');
	--
	DBMS_OUTPUT.PUT_LINE('set time off timing off veri off space 1 flush on pause off termout on numwidth 10;');
	DBMS_OUTPUT.PUT_LINE('set pagesize 50000 newpage 1 recsep off;');
	DBMS_OUTPUT.PUT_LINE('set trimspool on trimout on define "&" concat "." serveroutput on;');
	DBMS_OUTPUT.PUT_LINE('set underline on heading off echo off linesize 1500 termout on feedback off;');
	--
	FOR snapshot_info_rec IN cs_snapshot_info(databaseid, databasein, &&num_of_days) LOOP
		IF  report_start_snap# IS NULL
			OR report_start_snap# <= snapshot_info_rec.snap_id
		THEN
			IF is_first_time 
			THEN
				is_first_time := FALSE;
				begin_snap# := snapshot_info_rec.snap_id;
			ELSE
				IF end_snap# IS NOT NULL
				THEN
					begin_snap# := end_snap#;
				END IF;
				end_snap# := snapshot_info_rec.snap_id;
				--
				IF snapshot_info_rec.is_reboot_instance = 0
				THEN
					--
					-- AWR Report
					DBMS_OUTPUT.PUT_LINE(
						'spo '||'awrrpt_'
						|| TO_CHAR(begin_snap#)||'_'
						|| TO_CHAR(end_snap#)
						|| CASE 
								WHEN '&&comment' IS NULL 
								THEN '' 
								ELSE '_'||'&&comment' 
						   END
						|| '.html'
					);
					DBMS_OUTPUT.PUT_LINE(
						'SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML('
						|| ''''||databaseid||''','
						|| TO_CHAR(databasein)||','
						|| TO_CHAR(begin_snap#)||','
						|| TO_CHAR(end_snap#)||','
						|| '0));'
					);
					DBMS_OUTPUT.PUT_LINE('spo off;');
					--
					-- AWR SQL Report
					FOR sqlid_info_rec IN cs_sqlid_info(databaseid, databasein, end_snap#, C_TOPN) LOOP
						DBMS_OUTPUT.PUT_LINE(
							'spo '||'awrsqrpt_'
							|| TO_CHAR(begin_snap#)||'_'
							|| TO_CHAR(end_snap#)
							|| CASE 
									WHEN '&&comment' IS NULL 
									THEN '' 
									ELSE '_' || '&&comment'
							   END 
							||'_' || sqlid_info_rec.sql_id||'.html'
						);
						DBMS_OUTPUT.PUT_LINE(
							'SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_SQL_REPORT_HTML('
							|| ''''||databaseid||''','
							|| TO_CHAR(databasein)||','
							|| TO_CHAR(begin_snap#)||','
							|| TO_CHAR(end_snap#)||','
							|| ''''||sqlid_info_rec.sql_id||''','
							|| '0));'
						);
						DBMS_OUTPUT.PUT_LINE('spo off;');
					END LOOP;
				END IF;
			END IF;
		END IF;
	END LOOP;
END;
/
--
set serveroutput off;
spo off;
undefine comment;
undefine num_of_days;
undefine report_start_snapid;

clear buffer

whenever sqlerror continue;
whenever oserror continue;

@@awrreport_exec_batch.sql

set feedback on veri on trimspool off trimout off;

!rm awrreport_exec_batch.sql
!del awrreport_exec_batch.sql
