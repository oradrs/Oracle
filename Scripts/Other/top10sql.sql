col sql for a40
Prompt Top 10 by Buffer Gets:

set linesize 180
set pagesize 180
SELECT * FROM
(SELECT substr(sql_text,1,40) sql,sql_id,
        buffer_gets, executions, buffer_gets/(case when executions>0 then executions else 1 end) "Gets/Exec",
        hash_value,address
   FROM V$SQLAREA
  WHERE buffer_gets > 10000
 ORDER BY buffer_gets DESC)
WHERE rownum <= 10
;

Prompt Top 10 by Physical Reads:

set linesize 180
set pagesize 180
SELECT * FROM
(SELECT substr(sql_text,1,40) sql,sql_id,
        disk_reads, executions, disk_reads/(case when executions>0 then executions else 1 end) "Reads/Exec",
        hash_value,address
   FROM V$SQLAREA
  WHERE disk_reads > 1000
 ORDER BY disk_reads DESC)
WHERE rownum <= 10
;

Prompt Top 10 by Executions:

set linesize 180
set pagesize 180
SELECT * FROM
(SELECT substr(sql_text,1,40) sql,sql_id,
        executions, rows_processed, rows_processed/executions "Rows/Exec",
        hash_value,address
   FROM V$SQLAREA
  WHERE executions > 100
 ORDER BY executions DESC)
WHERE rownum <= 10
;

Prompt Top 10 by Parse Calls:

set linesize 180
set pagesize 180
SELECT * FROM
(SELECT substr(sql_text,1,40) sql,sql_id,
        parse_calls, executions, hash_value,address
   FROM V$SQLAREA
  WHERE parse_calls > 1000
 ORDER BY parse_calls DESC)
WHERE rownum <= 10
;

Prompt Top 10 by Sharable Memory:

set linesize 180
set pagesize 180
SELECT * FROM 
(SELECT substr(sql_text,1,40) sql,sql_id,
        sharable_mem, executions, hash_value,address
   FROM V$SQLAREA
  WHERE sharable_mem > 1048576
 ORDER BY sharable_mem DESC)
WHERE rownum <= 10
;

Prompt Top 10 by Version Count:

set linesize 180
set pagesize 180
SELECT * FROM 
(SELECT substr(sql_text,1,40) sql,sql_id,
        version_count, executions, hash_value,address
   FROM V$SQLAREA
  WHERE version_count > 20
 ORDER BY version_count DESC)
WHERE rownum <= 10
;
