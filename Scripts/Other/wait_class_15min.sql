--select  to_char(trunc(a.end_time,'MI'),'HH24:MI') end_time,
--b.wait_class wait_class,
--round((sum(a.time_waited) / 10),0) sample_count
--from    gv$waitclassmetric_history a,
--v$system_wait_class b
--where   a.wait_class# = b.wait_class# and
--b.wait_class != 'Idle'
----and inst_id=1
--GROUP BY  trunc(A.end_time,'MI'), b.wait_class
--order by   2,trunc(a.end_time,'MI'),3

SET line 190 pages 1234
SELECT    *
   FROM
      (SELECT    TO_CHAR(TRUNC(a.end_time,'MI'),'HH24:MI') end_time,
            b.wait_class wait_class                                ,
            ROUND((SUM(a.time_waited) / 10),0) sample_count
         FROM gv$waitclassmetric_history a,
            v$system_wait_class b
         WHERE a.wait_class#  = b.wait_class#
            AND b.wait_class != 'Idle'
            AND a.end_time >sysdate-1/24/4
         GROUP BY TRUNC(A.end_time,'MI'),
            b.wait_class
      ) PIVOT ( SUM(sample_count) FOR wait_class IN ('Application','Commit','Concurrency','Configuration','Network',
      'Other', 'Scheduler', 'System I/O', 'User I/O' ) )
   ORDER BY 1;
