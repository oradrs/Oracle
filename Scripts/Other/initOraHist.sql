-- To know history of change for init.ora param

SET lin 250 ver OFF;

COL instance_number FOR 9999 HEA 'Inst';
COL BEGIN_TIME FOR a20;
COL END_TIME FOR a20;
COL PARAMETER_NAME FOR a30;
COL value FOR a15;
COL prior_value FOR a15;
COL snap_id FOR 9999;
COL isdefault HEA 'isDefault';
COL ismodified HEA 'isMod';

WITH
all_parameters AS (
SELECT snap_id,
       dbid,
       instance_number,
       parameter_name,
       value,
       isdefault,
       ismodified,
       lag(value) OVER (PARTITION BY dbid, instance_number, parameter_hash ORDER BY snap_id) prior_value
  FROM dba_hist_parameter
--  WHERE snap_id BETWEEN 962 AND 1236
--    AND 'Y' = 'Y'
--    AND dbid = 2216605479
)
SELECT TO_CHAR(s.begin_interval_time, 'YYYY-MM-DD HH24:MI') begin_time,
       TO_CHAR(s.end_interval_time, 'YYYY-MM-DD HH24:MI') end_time,
       p.snap_id,
       --p.dbid,
       p.instance_number,
       p.parameter_name,
       p.value,
       p.isdefault,
       p.ismodified,
       p.prior_value
  FROM all_parameters p,
       dba_hist_snapshot s
 WHERE p.value != p.prior_value
   AND s.snap_id = p.snap_id
   AND s.dbid = p.dbid
   AND s.instance_number = p.instance_number
 ORDER BY
       s.begin_interval_time DESC,
       --p.dbid,
       p.instance_number,
       p.parameter_name;
