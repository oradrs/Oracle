-- FileName : FullTabScan_QryList.sql
-- 
-- Purpose : To list queries which has doen FULL TABLE SCAN
-- 
-- Output : output file will be generated in current dir
-- 
-- ------------------------------------------

SET HEA ON LIN 500 PAGES 100 TAB OFF FEED OFF ECHO OFF VER OFF TRIMS ON TRIM ON TI OFF TIMI OFF;
SET LONG 2000000 LONGC 2000 LIN 32767;
set markup html on spool on entmap off;

-- get current time
COL current_time NEW_V current_time FOR A15;
SELECT 'current_time: ' x, TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') current_time FROM DUAL;
-- spool and sql_text
-- SPO FullTabScan_QryList_&&current_time..txt;

-- html
spool FullTabScan_QryList_&&current_time..htm;

PRO 
PRO FTS Query List - Captured on &&current_time ('YYYYMMDD_HH24MISS').
PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PRO 

SELECT RowNum, 
       SQL_ID,
       SQL_TEXT
FROM DBA_HIST_SQLTEXT
WHERE SQL_ID IN (SELECT DISTINCT SQL_ID
                 FROM dba_hist_active_sess_history
                 WHERE sql_plan_options = 'FULL'
                 AND   SQL_OPNAME = 'SELECT'
                 AND   SQL_PLAN_OPERATION = 'TABLE ACCESS'
                 AND   SESSION_TYPE = 'FOREGROUND'
                 AND SQL_TEXT NOT LIKE '/* SQL Analyze%'
                 );

-- ------------------------------------------

-- spool off and cleanup
-- PRO
-- PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- PRO FullTabScan_QryList_&&current_time..txt has been generated
SPO OFF;
