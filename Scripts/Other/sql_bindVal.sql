-- Purpose : To get used bind values for SQLid

-- Sample OUTPUT : 
--    SNAP_ID | BEGIN_INTERVAL_TIME     | END_INTERVAL_TIME       | NAME | VALUE_STRING
--    ------+-------------------------+-------------------------+------+-------------
--       1103 | 2018-02-02 13:30:03:890 | 2018-02-02 14:30:09:517 | :2   | ABC       
--       1103 | 2018-02-02 13:30:03:890 | 2018-02-02 14:30:09:517 | :3   | 2017-06-19  
--       1104 | 2018-02-02 14:30:09:517 | 2018-02-02 15:30:13:580 | :2   | EFG       
--       1104 | 2018-02-02 14:30:09:517 | 2018-02-02 15:30:13:580 | :3   | 2017-06-19  

-- ------------------------------------------

undefine sqlid;

col VALUE_STRING format a50;
col NAME format a20;
col BEGIN_INTERVAL_TIME format a30;

SELECT sn.SNAP_ID,
       sn.BEGIN_INTERVAL_TIME,
       -- sn.END_INTERVAL_TIME,
       sb.NAME,
       sb.VALUE_STRING
FROM DBA_HIST_SQLBIND sb,
     DBA_HIST_SNAPSHOT sn
WHERE sb.sql_id = '&sqlid'
AND   sb.WAS_CAPTURED = 'YES'
AND   sn.snap_id = sb.snap_id
ORDER BY sb.snap_id,
         sb.NAME;

undefine sqlid;
