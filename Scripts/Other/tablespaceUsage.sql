-- Purpose : Data Files Usage 
-- Sample output :
--    TABLESPACE_NAME | DATAFILES | ALLOC_GB | USED_GB | PCT_USED | FREE_GB | PCT_FREE
--    ----------------+-----------+----------+---------+----------+---------+---------
--    SYSAUX          |         1 |       10 |       9 |     90.0 |       1 |     10.0
--    SYSTEM          |         1 |        1 |       1 |    100.0 |       0 |      0.0


WITH
alloc AS (
SELECT /*+  MATERIALIZE NO_MERGE  */ /* 2b.182 */
       tablespace_name,
       COUNT(*) datafiles,
       ROUND(SUM(bytes)/POWER(10,9)) gb
  FROM dba_data_files
 GROUP BY
       tablespace_name
),
free AS (
SELECT /*+  MATERIALIZE NO_MERGE  */ /* 2b.182 */
       tablespace_name,
       ROUND(SUM(bytes)/POWER(10,9)) gb
  FROM dba_free_space
 GROUP BY
       tablespace_name
),
tablespaces AS (
SELECT /*+  MATERIALIZE NO_MERGE  */ /* 2b.182 */
       a.tablespace_name,
       a.datafiles,
       a.gb alloc_gb,
       (a.gb - f.gb) used_gb,
       f.gb free_gb
  FROM alloc a, free f
 WHERE a.tablespace_name = f.tablespace_name
 ORDER BY
       a.tablespace_name
),
total AS (
SELECT /*+  MATERIALIZE NO_MERGE  */ /* 2b.182 */
       SUM(alloc_gb) alloc_gb,
       SUM(used_gb) used_gb,
       SUM(free_gb) free_gb
  FROM tablespaces
)
SELECT v.tablespace_name,
       v.datafiles,
       v.alloc_gb,
       v.used_gb,
       CASE WHEN v.alloc_gb > 0 THEN
       LPAD(TRIM(TO_CHAR(ROUND(100 * v.used_gb / v.alloc_gb, 1), '990.0')), 8)
       END pct_used,
       v.free_gb,
       CASE WHEN v.alloc_gb > 0 THEN
       LPAD(TRIM(TO_CHAR(ROUND(100 * v.free_gb / v.alloc_gb, 1), '990.0')), 8)
       END pct_free
  FROM (
SELECT tablespace_name,
       datafiles,
       alloc_gb,
       used_gb,
       free_gb
  FROM tablespaces
 UNION ALL
SELECT 'Total' tablespace_name,
       TO_NUMBER(NULL) datafiles,
       alloc_gb,
       used_gb,
       free_gb
  FROM total
) v;

-- ------------------------------------------
