-- Purpose : Script: Finding the Top N Queries for a User (AWR) 
-- Note : output matches with AWR - "SQL ordered by Elapsed Time"
-- Source : https://www.realdbamagic.com/script-finding-top-n-queries-user-awr/
-- ------------------------------------------


select sub.sql_id,
       txt.sql_text,
       parsing_schema_name,
       sub.seconds_since_date,
       sub.execs_since_date,
       sub.gets_since_date,
       round(sub.seconds_since_date / (sub.execs_since_date + 0.01), 3) avg_query_time
  from ( -- sub to sort before top N filter
        select sql_id,
                g.parsing_schema_name,
                round(sum(elapsed_time_delta) / 1000000) as seconds_since_date,
                sum(executions_delta) as execs_since_date,
                sum(buffer_gets_delta) as gets_since_date,
                row_number() over (order by round(sum(elapsed_time_delta) / 1000000) desc) r
          from dba_hist_snapshot natural
          join dba_hist_sqlstat g
         where begin_interval_time > sysdate - 7
           and parsing_schema_name = '&user_name'
         group by sql_id, g.parsing_schema_name) sub
  join dba_hist_sqltext txt on sub.sql_id = txt.sql_id
 where r < &N
 order by seconds_since_date desc;

-- ------------------------------------------
-- Same as above; But Using snap id instead of date range

select * from dba_hist_snapshot order by snap_id;
-- e.g.   output : 170 and 179

select sub.sql_id,
       txt.sql_text,
       parsing_schema_name,
       sub.seconds_since_date,
       sub.execs_since_date,
       sub.gets_since_date,
       round(sub.seconds_since_date / (sub.execs_since_date + 0.01), 3) avg_query_time_sec
  from ( -- sub to sort before top N filter
        select sql_id,
                g.parsing_schema_name,
                round(sum(elapsed_time_delta) / 1000000) as seconds_since_date,
                sum(executions_delta) as execs_since_date,
                sum(buffer_gets_delta) as gets_since_date,
                row_number() over (order by round(sum(elapsed_time_delta) / 1000000) desc) r
          from dba_hist_snapshot natural
          join dba_hist_sqlstat g
         where SNAP_ID between 170 and 179
         -- begin_interval_time > sysdate - 7
           and parsing_schema_name = '&user_name'
         group by sql_id, g.parsing_schema_name) sub
  join dba_hist_sqltext txt on sub.sql_id = txt.sql_id
 where r < 500
 order by seconds_since_date desc;

-- ------------------------------------------
-- get snap id range
select * from dba_hist_snapshot order by snap_id;

-- get unique sql_id between 2 snap id
SELECT s.sql_id
       , COUNT(*)
FROM DBA_HIST_SQLSTAT s
WHERE s.snap_id BETWEEN 4796 AND 4820
AND   PARSING_SCHEMA_NAME = '&user_name'
GROUP BY s.sql_id;

-- list of sqlid, text etc between 2 snap id; might get duplicates
SELECT t.sql_id
       , t.sql_text
       , s.executions_total
       , s.elapsed_time_total
FROM DBA_HIST_SQLSTAT s
     , DBA_HIST_SQLTEXT t
WHERE t.sql_id = s.sql_id
AND   s.snap_id BETWEEN 4796 AND 4820
AND   PARSING_SCHEMA_NAME = '&user_name';


 
