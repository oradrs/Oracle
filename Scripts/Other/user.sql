declare
  ls_exact varchar2(1) := 'Y';
  ls_username varchar2( 30 ) := upper( '&1' );

  cursor csr_user_dets is
    select username, default_tablespace, temporary_tablespace, created, profile
    from dba_users
    where ( (     ls_exact <> 'Y'
              and username like upper( '%&1%' ) )
             or
            (     ls_exact = 'Y'
              and username = ls_username )
          )
      and username not in ( 'SYS', 'SYSTEM' )
    order by username;

  cursor csr_sys_privs( xs_username in varchar2 ) is
    select *
    from dba_sys_privs
    where grantee = xs_username
    order by privilege;

  cursor c_dba_role_privs is
    select *
    from dba_role_privs
    where ( (     ls_exact <> 'Y'
              and grantee like upper( '%&1%' ) )
             or
            (     ls_exact = 'Y'
              and grantee = ls_username )
          )
    order by grantee;

  cursor c_ts_quotas is
    select *
    from dba_ts_quotas
    where ( (     ls_exact <> 'Y'
              and username like upper( '%&1%' ) )
             or
            (     ls_exact = 'Y'
              and username = ls_username )
          )
    order by username;

  i_loop_counter integer;
  s_sql_text varchar2( 200  );

begin

  if substr( '&1', 1, 1) = '=' then
    ls_exact := 'Y';
    ls_username := substr( upper( '&1' ), 2 );
  else
    ls_exact := 'N';
    ls_username := upper( '&1' );
  end if;
  dbms_output.put_line( ls_exact || ' ' || ls_username );

  if ls_exact = 'Y' then
    dbms_output.put_line( 'User Details : Search for exact match on ' || '''' || ls_username || '''' || chr(10) );
  else
    dbms_output.put_line( 'User Details : Search for all like ' || '''' || ls_username || '''' || chr(10) );
  end if;

  dbms_output.put_line( rpad( 'User Name', 20 ) || ' ' ||
                        rpad( 'Default T Space', 25 ) || ' ' ||
                        rpad( 'Temp T Space', 25 ) || ' ' ||
                        'Created         ' || '   ' ||
                        rpad( 'Profile', 25 ) );
  dbms_output.put_line( rpad( '---------', 20 ) || ' ' ||
                        rpad( '---------------', 25 ) || ' ' ||
                        rpad( '------------', 25 ) || ' ' ||
                        '-------         ' || '   ' ||
                        rpad( '-------', 25 ) );

  for i_csr_user_dets in csr_user_dets loop
    dbms_output.put_line( rpad( i_csr_user_dets.username, 20 ) || ' ' ||
                          rpad( i_csr_user_dets.default_tablespace, 25 ) || ' ' ||
                          rpad( i_csr_user_dets.temporary_tablespace, 25 ) || ' ' ||
                          to_char( i_csr_user_dets.created, 'dd/mm/yyyy hh24:mi' ) || '   ' ||
                          rpad( i_csr_user_dets.profile, 25 ) );
  end loop;

  dbms_output.put_line( chr(9) );
  dbms_output.put_line( 'System privileges' );
  for i_csr_user_dets in csr_user_dets loop
    i_loop_counter := 0;
    for i_csr_sys_privs in csr_sys_privs( i_csr_user_dets.username ) loop
      if i_loop_counter = 0 then
        s_sql_text := rpad( i_csr_user_dets.username, 14 ) || chr(9);
      else
        s_sql_text := chr(9) || chr(9);
      end if;
      if i_csr_sys_privs.admin_option = 'YES' then
        s_sql_text := s_sql_text || i_csr_sys_privs.privilege || ' with admin';
      else
        s_sql_text := s_sql_text || i_csr_sys_privs.privilege || ' (no admin)';
      end if;
      dbms_output.put_line( s_sql_text );
      i_loop_counter := i_loop_counter + 1 ;
    end loop;
    if i_loop_counter > 0 then
      dbms_output.put_line( chr(9) );
    end if;
  end loop;

  dbms_output.put_line( chr(9) );
  dbms_output.put_line( 'Roles' );

  dbms_output.put_line( rpad( 'Grantee', 30 ) || ' ' ||
                        rpad( 'Role', 30 ) || ' ' ||
                        rpad( 'Admin', 4 ) || ' ' ||
                        rpad( 'Default', 4 ) );

  dbms_output.put_line( rpad( '-------', 30 ) || ' ' ||
                        rpad( '----', 30 ) || ' ' ||
                        rpad( '-----', 4 ) || ' ' ||
                        rpad( '-------', 4 ) );

  for i_c_dba_role_privs in c_dba_role_privs loop
    dbms_output.put_line( rpad( i_c_dba_role_privs.grantee, 30 ) || ' ' ||
                          rpad( i_c_dba_role_privs.granted_role, 30 ) || ' ' ||
                          rpad( i_c_dba_role_privs.admin_option, 4 ) || ' ' ||
                          rpad( i_c_dba_role_privs.default_role, 4 ) );

  end loop;

  dbms_output.put_line( chr(10) );

  dbms_output.put_line( 'Tablespace quotas' || chr(10) );

  dbms_output.put_line( rpad( 'Tablespace', 30 ) || ' ' ||
                        rpad( 'User', 30 ) || ' ' ||
                        lpad( 'Bytes', 14 ) || ' ' ||
                        lpad( 'Max Bytes', 14 )  || ' ' ||
                        lpad( 'Blocks', 12 )  || ' ' ||
                        lpad('Max Blocks', 12 ) );

  dbms_output.put_line( rpad( '-------', 30 ) || ' ' ||
                        rpad( '----', 30 ) || ' ' ||
                        lpad( '--------', 14 ) || ' ' ||
                        lpad( '------------', 14 ) || ' ' ||
                        lpad( '------', 12 ) || ' ' ||
                        lpad( '----------', 12 ) );

  for i_c_ts_quotas in c_ts_quotas loop
    dbms_output.put_line( rpad( i_c_ts_quotas.tablespace_name, 30 ) || ' ' ||
                          rpad( i_c_ts_quotas.username, 30 ) || ' ' ||
                          to_char( ( i_c_ts_quotas.bytes ), '99999,999,999' ) || ' ' ||
                          to_char( ( i_c_ts_quotas.max_bytes ), '99999,999,999' ) || ' ' ||
                          to_char( ( i_c_ts_quotas.blocks ), '999,999,999' ) || ' ' ||
                          to_char( ( i_c_ts_quotas.max_blocks ), '999,999,999' ) );


  end loop;


end;
/
