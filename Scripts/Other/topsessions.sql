--  FILE:       topsessions.sql
--
--  AUTHOR:     Andy Rivenes
--  DATE:       05/15/2001
--
--  DESCRIPTION:
--              Script to list top resource intensive sessions. 
--
--
--  REQUIREMENTS:
--
--
--  MODIFICATIONS:
--
--              03/21/2003, AR, Modified to one query, removed non-essential
--                fields.
--              01/30/2004, AR, Added a timestamp output from the query.
--
SET VERIFY off;
SET LINESIZE 120;
SET SERVEROUTPUT on SIZE 1000000 FORMAT WRAPPED;
--
SET HEAD off;
ACCEPT var_status DEFAULT '' PROMPT 'ENTER session status (e.g. ACTIVE, INACTIVE, leave blank for all) > ';
ACCEPT var_uid DEFAULT '' PROMPT 'ENTER user name (leave blank for all) > ';
PROMPT ;
SET HEAD on;
--
DECLARE
  --
  CURSOR cusr_cur( cp_totcpu NUMBER, cp_logrds NUMBER, cp_phyrds NUMBER, cp_rdosz NUMBER, cp_srtdsk NUMBER, 
                   cp_status VARCHAR, cp_uid VARCHAR ) IS
    SELECT NVL(a.username,'UNKNOWN') uname,
           a.sid sid,
           a.serial# sernum,
           b.spid spid,
           a.osuser suser,
           a.status status,
           a.server server,
           a.machine smach,
           a.process process,
           a.program sprog,
           a.client_info cli,
           c.value/100 tcpu,
           d.value lrds,
           e.value prds,
           f.value/1024 rsz,
           h.value sd
      FROM V$SESSION a, 
           V$PROCESS b,
           V$SESSTAT c,
           V$SESSTAT d,
           V$SESSTAT e,
           V$SESSTAT f,
           V$SESSTAT h
     WHERE a.paddr = b.addr
       AND a.sid = c.sid
       AND a.sid = d.sid
       AND a.sid = e.sid
       AND a.sid = f.sid
       AND a.sid = h.sid
       AND c.statistic# = cp_totcpu
       AND d.statistic# = cp_logrds
       AND e.statistic# = cp_phyrds
       AND f.statistic# = cp_rdosz
       AND h.statistic# = cp_srtdsk
       AND a.type != 'BACKGROUND'
       AND a.status LIKE cp_status||'%'
       AND a.username LIKE cp_uid||'%'
     ORDER BY c.value DESC;
  --
  cusr_rec         cusr_cur%ROWTYPE;
  --
  var_totcpu       NUMBER;
  var_logrds       NUMBER;
  var_phyrds       NUMBER;
  var_rdosz        NUMBER;
  var_srtdsk       NUMBER;
  --
  var_sid          NUMBER;
  var_tcpu         NUMBER;
  var_lrds         NUMBER;
  var_prds         NUMBER;
  var_rsz          NUMBER;
  var_sd           NUMBER;
  --
  var_stat_row     INTEGER := 1;
  var_row_max      INTEGER := 20;
  --
  var_timestamp    VARCHAR2(21);
  var_cnt          INTEGER := 1;
--
BEGIN
  --
  SELECT statistic# 
    INTO var_totcpu
    FROM V$STATNAME  
   WHERE name = 'CPU used by this session';
  --
  SELECT statistic#
    INTO var_logrds
    FROM V$STATNAME  
   WHERE name = 'session logical reads';
  --
  SELECT statistic# 
    INTO var_phyrds 
    FROM V$STATNAME  
   WHERE name = 'physical reads';
  --
  SELECT statistic# 
    INTO var_rdosz 
    FROM V$STATNAME  
   WHERE name = 'redo size';
  --
  SELECT statistic# 
    INTO var_srtdsk 
    FROM V$STATNAME  
   WHERE name = 'sorts (disk)';
  --
  SELECT TO_CHAR(sysdate, 'MM/DD/YYYY HH24:MI:SS')
    INTO var_timestamp
    FROM dual;
  --
  DBMS_OUTPUT.PUT_LINE('Top '||TO_CHAR(var_row_max)||' Sessions, Timestamp: '||var_timestamp);
  --DBMS_OUTPUT.PUT_LINE( ''||var_timestamp);
  DBMS_OUTPUT.PUT_LINE(CHR(10));
  --
  DBMS_OUTPUT.PUT_LINE( '           User       DB   Serial    Server             Total CPU      Logical     Physical  Redo Size   Sorts' );
  DBMS_OUTPUT.PUT_LINE( '           Name      SID      Num       PID    Status   Time(Sec)        Reads        Reads   (KBytes)  (Disk)' );
  DBMS_OUTPUT.PUT_LINE( '---------------  -------  -------  --------  --------  ----------  -----------  -----------  ---------  ------' );
  --
--  var_stat_row := 1;
  OPEN cusr_cur(var_totcpu, var_logrds, var_phyrds, var_rdosz, var_srtdsk, UPPER('&var_status'), UPPER('&var_uid'));
   LOOP
    FETCH cusr_cur INTO cusr_rec;
 --   EXIT CUR1 WHEN cusr_cur%NOTFOUND;
    EXIT  WHEN cusr_cur%NOTFOUND;
    --
    var_cnt := var_cnt + 1;
    --
    IF var_stat_row <= var_row_max THEN
      DBMS_OUTPUT.PUT_LINE(   LPAD(cusr_rec.uname,15,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.sid,'999999'),8,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.sernum,'999999'),8,' ')||' '
                            ||LPAD(cusr_rec.spid,9,' ')||' '
                            ||LPAD(cusr_rec.status,9,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.tcpu,'9999990.99'),11,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.lrds,'999,999,990'),12,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.prds,'999,999,990'),12,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.rsz,'999,999,990'),12,' ')||' '
                            ||LPAD(TO_CHAR(cusr_rec.sd,'99,990'),7,' ')  );
      --
      var_stat_row := var_stat_row + 1;
    END IF;
--  END LOOP CUR1;
  END LOOP;
  CLOSE cusr_cur;
  DBMS_OUTPUT.PUT_LINE(CHR(10));
  DBMS_OUTPUT.PUT_LINE( 'Total sessions that meet criteria: '||var_cnt);
END;
/
