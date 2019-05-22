
SET FEED ON VER OFF HEA ON LIN 32767 PAGES 100 TIMI OFF LONG 80 LONGC 80 TRIMS ON AUTOT OFF;
ALTER SESSION SET nls_date_format='YYYY/MM/DD HH24:MI:SS';
COL current_time NEW_V current_time FOR A15 NOPRI;
SELECT 'current_time: ' x, TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') current_time FROM DUAL;
SPO DBsessions_&&current_time..txt

SET LONG 3000000 LONGC 300;

SELECT se.inst_id,
       se.SERIAL#,
       sid,
       username,
       status,
       schemaname,
       osuser,
       machine,
       PROGRAM,
       TYPE,
       logon_time,
       se.SQL_ID,
       sq.SQL_FULLTEXT
FROM gv$session se,
     gv$sql sq
WHERE se.TYPE = 'USER'
AND   sq.inst_id = se.inst_id
AND   sq.sql_id = se.sql_id
AND   sq.child_number = se.sql_child_number
order by se.inst_id, se.SQL_ID;

SPO OFF;
SET FEED ON VER ON LIN 80 PAGES 14 LONG 80 LONGC 80 TRIMS OFF;

