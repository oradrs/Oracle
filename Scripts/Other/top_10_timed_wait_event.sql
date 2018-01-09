/* Formatted on 08/21/2014 3:28:04 PM (QP5 v5.163.1008.3004) */
---##############################################
---Top 10 Foreground Events by Total Wait Time
---##############################################

 COL EVENT FOR a60  HEAD "Top 10 Foreground Events by Total Wait Time"
 COL Waits HEAD "Waits|"
 COL TIME HEAD "Total Wait|Time(sec)"
 COL AVWAIT HEAD "Wait|Avg(ms)"
 COL PCTWTT for 99999.9 HEAD "% DB|time"
 COL WCLS FOR a70 HEAD "Wait Class"

WITH snp
     AS (  SELECT DBID,
                  INSTANCE_NUMBER,
                  MIN (SNAP_ID) bid,
                  MAX (SNAP_ID) eid,
                  ROUND (
                     EXTRACT (
                        DAY FROM MAX (END_INTERVAL_TIME)
                                  - MIN (END_INTERVAL_TIME))
                     * 86400				  
                     + EXTRACT (
                        HOUR FROM MAX (END_INTERVAL_TIME)
                                  - MIN (END_INTERVAL_TIME))
                     * 3600
                     + EXTRACT (
                          MINUTE FROM MAX (END_INTERVAL_TIME)
                                      - MIN (END_INTERVAL_TIME))
                       * 60
                     + EXTRACT (
                          SECOND FROM MAX (END_INTERVAL_TIME)
                                      - MIN (END_INTERVAL_TIME)))
                     ets
             FROM DBA_HIST_SNAPSHOT
            WHERE INSTANCE_NUMBER = USERENV ('Instance')
                  AND snap_id BETWEEN &bid AND &eid
         --AND BEGIN_INTERVAL_TIME BETWEEN trunc(sysdate)-1 AND trunc(sysdate)
         GROUP BY DBID, INSTANCE_NUMBER),
     dbtime
     AS (SELECT NVL ( (e1.VALUE - b1.VALUE), -1) dbtimev
           FROM dba_hist_sys_time_model e1, dba_hist_sys_time_model b1, snp
          WHERE     b1.snap_id = snp.bid
                AND e1.snap_id = snp.eid
                AND b1.dbid = snp.DBID
                AND e1.dbid = snp.DBID
                AND b1.instance_number = snp.INSTANCE_NUMBER
                AND e1.instance_number = snp.INSTANCE_NUMBER
                AND b1.stat_name = 'DB time'
                AND b1.stat_id = e1.stat_id)
SELECT event,
       wtfg waits,
       ROUND (tmfg / 1000000, 1) time,
       ROUND (DECODE (wtfg, 0, TO_NUMBER (NULL), tmfg / wtfg) / 1000) avwait,
       ROUND (DECODE (dbtimev, 0, TO_NUMBER (NULL), tmfg / dbtimev) * 100, 1)
          pctwtt,
       wcls
  FROM (  SELECT event,
                 wtfg,
                 ttofg,
                 tmfg,
                 wcls
            FROM (SELECT e.event_name event,
                         CASE
                            WHEN e.total_waits_fg IS NOT NULL
                            THEN
                               e.total_waits_fg - NVL (b.total_waits_fg, 0)
                            ELSE
                               (e.total_waits - NVL (b.total_waits, 0))
                               - GREATEST (
                                    0,
                                    (NVL (ebg.total_waits, 0)
                                     - NVL (bbg.total_waits, 0)))
                         END
                            wtfg,
                         CASE
                            WHEN e.total_timeouts_fg IS NOT NULL
                            THEN
                               e.total_timeouts_fg
                               - NVL (b.total_timeouts_fg, 0)
                            ELSE
                               (e.total_timeouts - NVL (b.total_timeouts, 0))
                               - GREATEST (
                                    0,
                                    (NVL (ebg.total_timeouts, 0)
                                     - NVL (bbg.total_timeouts, 0)))
                         END
                            ttofg,
                         CASE
                            WHEN e.time_waited_micro_fg IS NOT NULL
                            THEN
                               e.time_waited_micro_fg
                               - NVL (b.time_waited_micro_fg, 0)
                            ELSE
                               (e.time_waited_micro
                                - NVL (b.time_waited_micro, 0))
                               - GREATEST (
                                    0,
                                    (NVL (ebg.time_waited_micro, 0)
                                     - NVL (bbg.time_waited_micro, 0)))
                         END
                            tmfg,
                         e.wait_class wcls
                    FROM dba_hist_system_event b,
                         dba_hist_system_event e,
                         dba_hist_bg_event_summary bbg,
                         dba_hist_bg_event_summary ebg,
                         snp
                   WHERE    
				   		/* 		   b.snap_id  (+) = :bid
         and e.snap_id      = :eid
         and bbg.snap_id (+) = :bid
         and ebg.snap_id (+) = :eid
         and e.dbid          = :dbid
         and e.instance_number = :inst_num
		 b.snap_id(+) = snp.bid
          */      			 bbg.snap_id (+)= 35279
                         AND b.snap_id(+) =35279
                         AND ebg.snap_id (+) = 35280
                         AND e.snap_id = snp.eid
                         AND e.dbid = snp.DBID
                         AND e.instance_number = snp.INSTANCE_NUMBER
                         AND e.dbid = b.dbid(+)
                         AND e.instance_number = b.instance_number(+)
                         AND e.event_id = b.event_id(+)
                         AND e.dbid = ebg.dbid(+)
                         AND e.instance_number = ebg.instance_number(+)
                         AND e.event_id = ebg.event_id(+)
                         AND e.dbid = bbg.dbid(+)
                         AND e.instance_number = bbg.instance_number(+)
                         AND e.event_id = bbg.event_id(+)
                         AND e.total_waits > NVL (b.total_waits, 0)
                         AND e.wait_class <> 'Idle'
                  UNION ALL
                  SELECT 'DB CPU' event,
                         TO_NUMBER (NULL) wtfg,
                         TO_NUMBER (NULL) ttofg,
                         NVL ( (e1.VALUE - b1.VALUE), -1) tmfg,
                            ' '                           wcls
                    FROM dba_hist_sys_time_model e1,
                         dba_hist_sys_time_model b1,
                         snp,
                         dbtime
                   WHERE     b1.snap_id = snp.bid
                         AND e1.snap_id = snp.eid
                         AND b1.dbid = snp.DBID
                         AND e1.dbid = snp.DBID
                         AND b1.instance_number = snp.INSTANCE_NUMBER
                         AND e1.instance_number = snp.INSTANCE_NUMBER
                         AND b1.stat_name = 'DB CPU'
                         AND b1.stat_id = e1.stat_id
				UNION ALL
				SELECT ' ' event,
                         TO_NUMBER (NULL) wtfg,
                         TO_NUMBER (NULL) ttofg,
                         TO_NUMBER (NULL)  tmfg,
                            '------------ For Inst-'
                         || snp.INSTANCE_NUMBER
                         || ' btwn snap_id '
                         || snp.bid
                         || ' and '
                         || snp.eid
                         || CHR (10)
                         || '------------ Elp Time '
                         || ROUND (ets / 60, 2)
                         || '(mins) and DB Time '
                         || ROUND (dbtimev / 1000000 / 60, 2)
                         || '(mins)'
                            wcls from
                         snp,
                         dbtime )
        ORDER BY tmfg DESC, wtfg DESC, event),
       dbtime
 WHERE (ROWNUM <= 11 AND tmfg > 0) or wcls like '%For Inst%'
 ;

						 
						 
