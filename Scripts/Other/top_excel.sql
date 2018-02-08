-- Source : https://github.com/gwenshap/Oracle-DBA-Scripts/blob/master/top_excel.sql
-- Sample :
--    SNAP_ID | RANK | GETS_SQL                  | CPU_SQL                 | ELAPSED_SQL             | EXECUTIONS_SQL        
--    --------+------+---------------------------+-------------------------+-------------------------+-----------------------
--       1038 |    1 | 6185567: 6mcpb06rctk0x    | 543.97: 7pp6h4hj0djcf   | 7114.66: 7pp6h4hj0djcf  | 27077: f63rfdamawhv2  
--       1038 |    2 | 4661999: 6zda9fh0p6n3z    | 236.05: b6usrg82hwsa3   | 3555.05: b6usrg82hwsa3  | 13419: afcz9s4uazbpk  
--       1038 |    3 | 4576013: f63rfdamawhv2    | 93.28: 7nrhqb011sv5x    | 3283.73: 6mcpb06rctk0x  | 774: 3c1kubcdjnppq    
--       1038 |    4 | 3896237: 7pp6h4hj0djcf    | 59.66: 08336g5uhv9g3    | 1714.83: 8szmwam7fysa3  | 709: bjf05cwcj5s6p    
--       1038 |    5 | 2099866: 7nrhqb011sv5x    | 44.84: fhf8upax5cxsz    | 1405.7: 7wgks43wrjtrz   | 627: 9tgj4g8y4rwy8    
--       1039 |    1 | 6805358: 7nrhqb011sv5x    | 433.92: b6usrg82hwsa3   | 3514.15: b6usrg82hwsa3  | 13263: afcz9s4uazbpk  
--       1039 |    2 | 3369591: b6usrg82hwsa3    | 198.19: 7nrhqb011sv5x   | 1118.17: 3gfkgk7xfzgd4  | 11491: 0kkhhb2w93cx0  

-- ------------------------------------------
select * from dba_hist_snapshot order by snap_id
108 132
-- ------------------------------------------

with awr_ranks as
(
select snap_id, sql_id,
                           buffer_gets_delta,
                           dense_rank() over (partition by snap_id order by buffer_gets_delta desc) gets_rank,
                           cpu_time_delta,
                           dense_rank() over (partition by snap_id order by cpu_time_delta desc) cpu_rank,
                           elapsed_time_delta,
                           dense_rank() over (partition by snap_id order by elapsed_time_delta desc) elapsed_rank,
                           executions_delta,
                           dense_rank() over (partition by snap_id order by executions_delta desc) executions_rank
                     from sys.wrh$_sqlstat
), rank as
(
       select level rank from dual connect by level <= 5
)
select snap_id,
                           rank,
                           max(case gets_rank when rank then to_char(buffer_gets_delta)||': '||sql_id end) gets_sql,
                           max(case cpu_rank when rank then to_char(round(cpu_time_delta/1000000,2))||': '||sql_id end) cpu_sql,
                           max(case elapsed_rank when rank then to_char(round(elapsed_time_delta/1000000,2))||': '||sql_id end) elapsed_sql,
                           max(case executions_rank when rank then  to_char(executions_delta)||': '||sql_id end) executions_sql
              from awr_ranks, rank
              where snap_id between 110 and 131
              group by snap_id, rank
              order by snap_id, rank;
