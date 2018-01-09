select sql_id,substr(sql_text,1,50) "SQL",
                                      (cpu_time/1000000) "CPU_Seconds",
                                      disk_reads "Disk_Reads",
                                      buffer_gets "Buffer_Gets",
                                      executions "Executions",
                                      case when rows_processed = 0 then null
                                           else round((buffer_gets/nvl(replace(rows_processed,0,1),1))) 
                                           end "Buffer_gets/rows_proc",
                                      round((buffer_gets/nvl(replace(executions,0,1),1))) "Buffer_gets/executions",
                                      (elapsed_time/1000000) "Elapsed_Seconds",
                                      module "Module"
                                 from v$sql s
                                order by buffer_gets desc nulls last
