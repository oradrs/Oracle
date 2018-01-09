--http://ajwatblog.blogspot.in/2011/04/free-space-fragmentation-by-tablespace.html fsfi
--http://martincarstenbach.wordpress.com/2014/01/27/massive-tablespace-fragmentation-on-lmt-with-assm/
SET line 190
SET pages 154
SET pause OFF 
set verify off
set feed off
column pct_increase format 999 heading "PCT|INCR"
column "% Used" format 999.99
column "MB free" format 99999990.99
column "MB total" format 99999990.99
column "total blks" format 99999990
column "Extents" format 99999990
column tablespace_name format a30 heading TABLESPACE
column autoextensible format a6 heading "Auto|Extend"
column EXTENT_MANAGEMENT format a10 heading "Extend|Mgmt"
column SEGMENT_SPACE_MANAGEMENT format a6 heading "SegSpc|Mgmt"
column ALLOCATION_TYPE format a9 heading "Allocatio| Type"
column CONTENTS format a9 heading "Contents"
column EXTENTS format 99999990 heading "NoOf|Extents" Jus R
column FREE_CHUNKS format 99999990 heading "Free|Chunck" Jus R
column LARGEST_CHUNK_MB format 99999990 heading "Largest|Chunck(Mb)" Jus R
column FRAGMENTATION_INDEX format 99999990 heading "Fragment|Index" Jus R
BREAK ON report
compute SUM OF "GB total" ON report
compute SUM OF "GB free" ON report
var ts varchar2(40) ;
--PROMPT 'Enter tablespace_name (null for all) :'
exec :ts := '%'||upper(trim('&1'))||'%' ;

WITH /*+ rule */ df AS
     (SELECT   tablespace_name, SUM (BYTES) / 1024 / 1024 / 1024 gb
          FROM dba_temp_files
         WHERE tablespace_name LIKE (:ts)
      GROUP BY tablespace_name
      UNION ALL
      SELECT   tablespace_name, SUM (BYTES) / 1024 / 1024 / 1024 gb
          FROM dba_data_files
         WHERE tablespace_name LIKE (:ts)
      GROUP BY tablespace_name),
     fs AS
     (SELECT   tablespace_name, SUM (BYTES) / 1024 / 1024 / 1024 gb,
               COUNT (*) free_chunks,
               DECODE (ROUND ((MAX (BYTES) / 1048576), 2),
                       NULL, 0,
                       ROUND ((MAX (BYTES) / 1048576), 2)
                      ) largest_chunk_mb,
               NVL (ROUND (  SQRT (MAX (blocks) / SUM (blocks))
                           * (100 / SQRT (SQRT (COUNT (blocks)))),
                           2
                          ),
                    0
                   ) fragmentation_index
          FROM dba_free_space b
         WHERE tablespace_name LIKE (:ts)
      GROUP BY tablespace_name),
     ds AS
     (SELECT   tablespace_name, SUM (BYTES) / 1024 / 1024 / 1024 gb,
               SUM (extents) sum_ex
          FROM dba_segments a WHERE tablespace_name LIKE (:ts)
      GROUP BY tablespace_name),
     fil AS
     (SELECT tablespace_name, MAX (autoextensible) autoextensible
                 FROM dba_data_files
                WHERE tablespace_name LIKE (:ts)
             GROUP BY tablespace_name
      UNION ALL
      SELECT tablespace_name, MAX (autoextensible) autoextensible
                 FROM dba_temp_files
                WHERE tablespace_name LIKE (:ts)
             GROUP BY tablespace_name),
     fil2 AS
     (SELECT tablespace_name, CONTENTS, segment_space_management,
                      allocation_type, extent_management
                 FROM dba_tablespaces WHERE tablespace_name LIKE (:ts))
SELECT   df.tablespace_name,
         ROUND (NVL (fs.gb, df.gb - NVL (ds.gb, 0)), 2) "GB free",
         ROUND (df.gb, 2) "GB total",
         (df.gb - NVL (fs.gb, df.gb - NVL (ds.gb, 0))) * 100 / df.gb "% Used",
         fil2.CONTENTS, fil.autoextensible, fil2.extent_management,
         fil2.segment_space_management, fil2.allocation_type,
         NVL (ds.sum_ex, 0) extents, NVL (free_chunks, 0) free_chunks,
         NVL (largest_chunk_mb, 0) largest_chunk_mb,
         NVL (fragmentation_index, 0) fragmentation_index
    FROM df, fs, ds, fil, fil2
   WHERE df.tablespace_name = fs.tablespace_name(+)
     AND df.tablespace_name = ds.tablespace_name(+)
     AND df.tablespace_name = fil.tablespace_name(+)
     AND df.tablespace_name = fil2.tablespace_name(+)
ORDER BY "% Used" DESC;
undef 1
set feed on
set verify on
