set serveroutput on
set feed off
declare 
cursor c1 is select version
from v$instance;
cursor c2 is
    select
          host_name
       ,  instance_name
       ,  to_char(sysdate, 'HH24:MI:SS DD-MON-YY') currtime
       ,  to_char(startup_time, 'HH24:MI:SS DD-MON-YY') starttime
     from v$instance;
cursor c4 is
select * from (SELECT count(*) cnt, substr(event,1,50) event
FROM v$session_wait
WHERE wait_time = 0
AND event NOT IN ('smon timer','pipe get','wakeup time manager','pmon timer','rdbms ipc message',
'SQL*Net message from client')
GROUP BY event
ORDER BY 1 DESC) where rownum <6;
cursor c5 is
select round(sum(value)/1048576) as sgasize from v$sga;
cursor c6 is select round(sum(bytes)/1048576) as dbsize
from v$datafile;
cursor c7 is select 'top physical i/o process' category, sid,
       username, total_user_io amt_used,
       round(100 * total_user_io/total_io,2) pct_used
from (select b.sid sid, nvl(b.username, p.name) username,
             sum(value) total_user_io
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
      and b.sid = a.sid
      and c.name in ('physical reads', 'physical writes',
                     'physical reads direct',
                     'physical reads direct (lob)',
                     'physical writes direct',
                     'physical writes direct (lob)')
      and b.username not in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP')
      group by b.sid, nvl(b.username, p.name)
      order by 3 desc),
     (select sum(value) total_io
      from v$statname c, v$sesstat a
      where a.statistic# = c.statistic#
      and c.name in ('physical reads', 'physical writes',
                       'physical reads direct',
                       'physical reads direct (lob)',
                       'physical writes direct',
                       'physical writes direct (lob)'))
where rownum < 2
union all
select 'top logical i/o process ', sid, username,
       total_user_io amt_used,
       round(100 * total_user_io/total_io,2) pct_used
from (select b.sid sid, nvl(b.username, p.name) username,
             sum(value) total_user_io
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
      and b.sid = a.sid
      and c.name in ('consistent gets', 'db block gets')
      and b.username not in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP')
      group by b.sid, nvl(b.username, p.name)
      order by 3 desc),
     (select sum(value) total_io
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
 and b.sid = a.sid
      and c.name in ('consistent gets', 'db block gets'))
where rownum < 2
union all
select 'top memory process      ', sid,
       username, total_user_mem,
       round(100 * total_user_mem/total_mem,2)
from (select b.sid sid, nvl(b.username, p.name) username,
             sum(value) total_user_mem
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
      and b.sid = a.sid
      and c.name in ('session pga memory', 'session uga memory')
      and b.username not in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP')
      group by b.sid, nvl(b.username, p.name)
      order by 3 desc),
     (select sum(value) total_mem
      from v$statname c, v$sesstat a
      where a.statistic# = c.statistic#
      and c.name in ('session pga memory', 'session uga memory'))
where rownum < 2
union all
select 'top cpu process         ', sid, username,
       total_user_cpu,
       round(100 * total_user_cpu/greatest(total_cpu,1),2)
from (select b.sid sid, nvl(b.username, p.name) username,
             sum(value) total_user_cpu
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
      and b.sid = a.sid
      and c.name = 'CPU used by this session'
      and b.username not in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP')
      group by b.sid, nvl(b.username, p.name)
      order by 3 desc),
     (select sum(value) total_cpu
      from v$statname c, v$sesstat a,
           v$session b, v$bgprocess p
      where a.statistic# = c.statistic#
      and p.paddr (+) = b.paddr
      and b.sid = a.sid
      and c.name = 'CPU used by this session')
where rownum < 2;


cursor c8 is select username, sum(VALUE/100) cpu_usage_sec
from v$session ss, v$sesstat se, v$statname sn
where se.statistic# = sn.statistic#
and name like '%CPU used by this session%'
and se.sid = ss.sid
and username is not null
and username not in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP')
group by username
order by 2 desc;

begin
/*
dbms_output.put_line ('Database Version');
dbms_output.put_line ('~~~~~~~~~~~~~~~~');
for rec in c1
loop
dbms_output.put_line(rec.version);
end loop;
dbms_output.put_line( chr(13) );
dbms_output.put_line('Hostname');
dbms_output.put_line ('~~~~~~~~~~');
for rec in c2
loop
     dbms_output.put_line(rec.host_name);
end loop;
dbms_output.put_line( chr(13) );
dbms_output.put_line('SGA Size (MB)');
dbms_output.put_line('~~~~~~~~~~~~~');
for rec in c5
loop
     dbms_output.put_line(rec.sgasize);
end loop;
dbms_output.put_line( chr(13) );
dbms_output.put_line('Database Size (MB)');
dbms_output.put_line('~~~~~~~~~~~~~~~~~~');
for rec in c6
loop
     dbms_output.put_line(rec.dbsize);
end loop;
*/
dbms_output.put_line( chr(13) );
dbms_output.put_line('Instance start-up time');
dbms_output.put_line ('~~~~~~~~~~~~~~~~~~~~~~');
for rec in c2 loop
 dbms_output.put_line( rec.starttime );
  end loop;
dbms_output.put_line( chr(13) );
  for b in
    (select total, active, inactive, system, killed
    from
       (select count(*) total from v$session)
     , (select count(*) system from v$session where username is null)
     , (select count(*) active from v$session where status = 'ACTIVE' and username is not null)


     , (select count(*) inactive from v$session where status = 'INACTIVE')
     , (select count(*) killed from v$session where status = 'KILLED')) loop
dbms_output.put_line('Active Sessions');
dbms_output.put_line ('~~~~~~~~~~~~~~~');
dbms_output.put_line(b.total || ' sessions: ' || b.inactive || ' inactive,' || b.active || ' active, ' || b.system || ' system, ' || b.killed || ' killed ');
  end loop;
  dbms_output.put_line( chr(13) );
 dbms_output.put_line( 'Sessions Waiting' );
  dbms_output.put_line( chr(13) );
dbms_output.put_line('Count      Event Name');
dbms_output.put_line('~~~~~      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
for rec in c4 
loop
dbms_output.put_line(rec.cnt||'          '||rec.event);
end loop;
dbms_output.put_line( chr(13) );


dbms_output.put_line('-----      -----------------------------------------------------');
dbms_output.put_line(chr(13));


dbms_output.put_line('TOP Physical i/o, logical i/o, memory and CPU processes');
dbms_output.put_line ('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
for rec in c7
loop
dbms_output.put_line (rec.category||' : SID '||rec.sid||'	; User : '||rec.username||'	; Amount used :'||LPAD(TO_number(rec.amt_used,'99999999999999'),11,' ')||'		; Percent used: '||rec.pct_used);
end loop;


dbms_output.put_line('------------------------------------------------------------------');


dbms_output.put_line('TOP CPU users by usage');
dbms_output.put_line ('~~~~~~~~~~~~~~~~~~~~~');
for rec in c8
loop


dbms_output.put_line (rec.username||'--'||rec.cpu_usage_sec);
dbms_output.put_line ('---------------');
end loop;


end;
/
set feed on
