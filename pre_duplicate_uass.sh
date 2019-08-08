#!/usr/bin/ksh
print "this is $0"

# This script is run before refreshing the UASS database
# UASS specific passwords are saved in a file
# Schema ASSUROL_SEC is dumped
# Table assurol.t_parametres is dumped

# Environment variables
export ORACLE_SID=UASS
export ORACLE_HOME=/oracle/product/12.1

# Connection string
connect='/ as sysdba'

# Save UASS db passwords, excludes usernames with string SYS
cat <<! | $ORACLE_HOME/bin/sqlplus -s $connect
set lines 200
set pages 0
set trimspool on
set feedback off
set heading off
spool savepwdUASS.cmd
select
'alter user "'||username||'" identified by values '''||extract(xmltype(dbms_metadata.get_xml('USER',username)),'//USER_T/PASSWORD/text()').getStringVal()||''';'  old_password
  from dba_users
 order by user
/
spool off
!

# Prepare for datapump dumps

# Check on filesystem directory associated with Oracle Directory
[[ ! -d /oracle/oradata/dupdump ]] && mkdir -p /oracle/oradata/dupdump

# Create directory DUP_PUMP_DIR
$ORACLE_HOME/bin/sqlplus -s $connect <<!
drop directory DUP_PUMP_DIR;
create directory DUP_PUMP_DIR as '/oracle/oradata/dupdump';
grant read,write on directory DUP_PUMP_DIR to SYS;
!

# Dump schema ASSUROL_SEC
$ORACLE_HOME/bin/expdp \"$connect\" directory=DUP_PUMP_DIR \
                                    dumpfile=UASS_ASSUROL_SEC.dmp \
                                    LOGfile=UASS_ASSUROL_SEC.txt \
                                    schemas=ASSUROL_SEC \
                                    reuse_dumpfiles=y \
                                    content=all 

# Dump parameter table for schema assurol
$ORACLE_HOME/bin/expdp \"$connect\" directory=DUP_PUMP_DIR \
                                    dumpfile=UASS_ASSUROL_t_parametres.dmp \
                                    logfile=UASS_ASSUROL_t_parametres.txt \
                                    tables=assurol.t_parametres \
                                    reuse_dumpfiles=y \
                                    content=all
