-- Purpose : To get Top SQL
-- Modify MODULE value in query if required.
--
-- Output Sample : 
--    SQL_ID        | CPU_RANK | ELAPSED_RANK | DISKREAD_RANK | BUFFERGET_RANK | EXECUTIONS_TOTAL
--    --------------+----------+--------------+---------------+----------------+-----------------
--    d6j70k1252trk |        1 |            1 |             2 |              1 |               39
--    cajx95kx9cf8y |        2 |            5 |            11 |              7 |               25
--    5b4kbxt1f24ys |        3 |            4 |             3 |              2 |                1
--    1md6u8shbx6n3 |        4 |            8 |             1 |              6 |               21
--    0tjvgt9usd6u3 |        5 |            3 |            12 |              3 |                3


select tab1.sql_id,hist.sql_text ,tab1.cpu_rank, tab1.elapsed_rank ,DISKREAD_rank,BUFFERGET_rank,executions_total from dba_hist_sqltext hist,
(
-- top cpu
SELECT sql_id, elapsed_rank, cpu_rank,DISKREAD_rank,BUFFERGET_rank, executions_total
FROM (SELECT s.sql_id,
RANK() OVER (ORDER BY (MAX(s.CPU_TIME_TOTAL / s.executions_total)) DESC) cpu_rank,
RANK() OVER (ORDER BY (MAX(s.ELAPSED_TIME_TOTAL / s.executions_total)) DESC) elapsed_rank,
RANK() OVER (ORDER BY (MAX(s.DISK_READS_TOTAL / s.executions_total)) DESC) DISKREAD_rank ,
RANK() OVER (ORDER BY (MAX(s.BUFFER_GETS_TOTAL / s.executions_total)) DESC) BUFFERGET_rank ,
MAX(s.executions_total) executions_total
FROM dba_hist_sqlstat s,
dba_hist_snapshot sn
WHERE sn.begin_interval_time BETWEEN SYSDATE -10 AND SYSDATE
AND sn.snap_id = s.snap_id
AND s.executions_total > 0
and s.PARSING_SCHEMA_NAME <> 'SYS'
and MODULE = 'JDBC Thin Client'
GROUP BY s.sql_id
ORDER BY cpu_rank)
WHERE cpu_rank <= 500
UNION
-- top elapsed time
SELECT sql_id, elapsed_rank, cpu_rank, DISKREAD_rank,BUFFERGET_rank,executions_total
FROM (SELECT s.sql_id,
RANK() OVER (ORDER BY (MAX(s.CPU_TIME_TOTAL / s.executions_total)) DESC) cpu_rank,
RANK() OVER (ORDER BY (MAX(s.ELAPSED_TIME_TOTAL / s.executions_total)) DESC) elapsed_rank,
RANK() OVER (ORDER BY (MAX(s.DISK_READS_TOTAL / s.executions_total)) DESC) DISKREAD_rank ,
RANK() OVER (ORDER BY (MAX(s.BUFFER_GETS_TOTAL / s.executions_total)) DESC) BUFFERGET_rank ,
MAX(s.executions_total) executions_total
FROM dba_hist_sqlstat s,
dba_hist_snapshot sn
WHERE sn.begin_interval_time BETWEEN SYSDATE -10 AND SYSDATE
AND sn.snap_id = s.snap_id
AND s.executions_total > 0
and s.PARSING_SCHEMA_NAME <> 'SYS'
and MODULE = 'JDBC Thin Client'
GROUP BY s.sql_id
ORDER BY elapsed_rank)
WHERE elapsed_rank <= 500
UNION
-- top diskread
SELECT sql_id, elapsed_rank, cpu_rank, DISKREAD_rank,BUFFERGET_rank,executions_total
FROM (SELECT s.sql_id,
RANK() OVER (ORDER BY (MAX(s.CPU_TIME_TOTAL / s.executions_total)) DESC) cpu_rank,
RANK() OVER (ORDER BY (MAX(s.ELAPSED_TIME_TOTAL / s.executions_total)) DESC) elapsed_rank,
RANK() OVER (ORDER BY (MAX(s.DISK_READS_TOTAL / s.executions_total)) DESC) DISKREAD_rank ,
RANK() OVER (ORDER BY (MAX(s.BUFFER_GETS_TOTAL / s.executions_total)) DESC) BUFFERGET_rank ,
MAX(s.executions_total) executions_total
FROM dba_hist_sqlstat s,
dba_hist_snapshot sn
WHERE sn.begin_interval_time BETWEEN SYSDATE -10 AND SYSDATE
AND sn.snap_id = s.snap_id
AND s.executions_total > 0
and s.PARSING_SCHEMA_NAME <> 'SYS'
and MODULE = 'JDBC Thin Client'
GROUP BY s.sql_id
ORDER BY DISKREAD_rank)
WHERE DISKREAD_rank <= 500

UNION
-- top buffer gets
SELECT sql_id, elapsed_rank, cpu_rank, DISKREAD_rank,BUFFERGET_rank,executions_total
FROM (SELECT s.sql_id,
RANK() OVER (ORDER BY (MAX(s.CPU_TIME_TOTAL / s.executions_total)) DESC) cpu_rank,
RANK() OVER (ORDER BY (MAX(s.ELAPSED_TIME_TOTAL / s.executions_total)) DESC) elapsed_rank,
RANK() OVER (ORDER BY (MAX(s.DISK_READS_TOTAL / s.executions_total)) DESC) DISKREAD_rank ,
RANK() OVER (ORDER BY (MAX(s.BUFFER_GETS_TOTAL / s.executions_total)) DESC) BUFFERGET_rank ,
MAX(s.executions_total) executions_total
FROM dba_hist_sqlstat s,
dba_hist_snapshot sn
WHERE sn.begin_interval_time BETWEEN SYSDATE -10 AND SYSDATE
AND sn.snap_id = s.snap_id
AND s.executions_total > 0
and s.PARSING_SCHEMA_NAME <> 'SYS'
and MODULE = 'JDBC Thin Client'
GROUP BY s.sql_id
ORDER BY BUFFERGET_rank)
WHERE BUFFERGET_rank <= 500

UNION
-- total exec
SELECT sql_id, elapsed_rank, cpu_rank,DISKREAD_rank,BUFFERGET_rank,executions_total
FROM (
SELECT sql_id, elapsed_rank, cpu_rank,DISKREAD_rank,BUFFERGET_rank,executions_total
FROM (SELECT s.sql_id,
RANK() OVER (ORDER BY (MAX(s.CPU_TIME_TOTAL / s.executions_total)) DESC) cpu_rank,
RANK() OVER (ORDER BY (MAX(s.ELAPSED_TIME_TOTAL / s.executions_total)) DESC) elapsed_rank ,
RANK() OVER (ORDER BY (MAX(s.DISK_READS_TOTAL / s.executions_total)) DESC) DISKREAD_rank ,
RANK() OVER (ORDER BY (MAX(s.BUFFER_GETS_TOTAL / s.executions_total)) DESC) BUFFERGET_rank ,
MAX(s.executions_total) executions_total
FROM dba_hist_sqlstat s,
dba_hist_snapshot sn
WHERE sn.begin_interval_time BETWEEN SYSDATE -10 AND SYSDATE
AND sn.snap_id = s.snap_id
AND s.executions_total > 0
and s.PARSING_SCHEMA_NAME <> 'SYS'
-- and MODULE = 'JDBC Thin Client' -- consider only sqls executed from application
group by s.sql_id
) ORDER BY executions_total desc ) fetch first 500 rows only

) tab1 where hist.sql_id = tab1.sql_id
order by tab1.cpu_rank, tab1.elapsed_rank , DISKREAD_rank , BUFFERGET_rank ,executions_total ; 
