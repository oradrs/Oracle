set line 190 pages 1234
SELECT *
FROM (SELECT RANK () OVER (PARTITION BY "Snap Day" ORDER BY "CPU Time"
+ "Disk Reads"
+ "Buffer Gets"
+ "Writes"
+ "Sorts"
+ "Parses" DESC) AS "Rank",
i1.*
FROM (SELECT TO_CHAR (hs.begin_interval_time,
'MM/DD/YY'
) "Snap Day",
shs.sql_id "Sql id",
REPLACE
(CAST
(DBMS_LOB.SUBSTR (sht.sql_text, 20) AS VARCHAR (20)
),
CHR (10),
''
) "Sql",
SUM (shs.executions_delta) "Execs",
ROUND ( (SUM (shs.elapsed_time_delta) / 1000000)
/ SUM (shs.executions_delta),
1
) "Time Ea Sec",
ROUND ( (SUM (shs.cpu_time_delta) / 1000000)
/ SUM (shs.executions_delta),
1
) "CPU Ea Sec",
ROUND ( (SUM (shs.iowait_delta) / 1000000)
/ SUM (shs.executions_delta),
1
) "IO/Wait Ea Sec",
SUM (shs.cpu_time_delta) "CPU Time",
SUM (shs.disk_reads_delta) "Disk Reads",
SUM (shs.buffer_gets_delta) "Buffer Gets",
SUM (shs.direct_writes_delta) "Writes",
SUM (shs.parse_calls_delta) "Parses",
SUM (shs.sorts_delta) "Sorts",
SUM (shs.elapsed_time_delta) "Elapsed"
FROM dba_hist_sqlstat shs INNER JOIN dba_hist_sqltext sht
ON (sht.sql_id = shs.sql_id)
INNER JOIN dba_hist_snapshot hs
ON (shs.snap_id = hs.snap_id)
HAVING SUM (shs.executions_delta) > 0
GROUP BY shs.sql_id,
TO_CHAR (hs.begin_interval_time, 'MM/DD/YY'),
CAST (DBMS_LOB.SUBSTR (sht.sql_text, 20) AS VARCHAR (20)
)
ORDER BY "Snap Day" DESC) i1
ORDER BY "Snap Day" DESC)
WHERE "Rank" <= 20 
AND "Snap Day" between TO_CHAR (SYSDATE-4, 'MM/DD/YY') and TO_CHAR (SYSDATE, 'MM/DD/YY');  --change analyze period here
