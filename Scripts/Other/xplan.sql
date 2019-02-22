-- preferable setting before running SQL
-- alter session set statistics_level=ALL;
-- set serverout off;

set line 1000 pagesize 100;
spool c:\temp\a1.log;
SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR(null,null,FORMAT=>'ALLSTATS LAST'));
spool off;
prompt --------------------------;
Prompt *** Check file c:\temp\a1.log - for xplan output;
prompt;
