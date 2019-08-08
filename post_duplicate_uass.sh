#!/usr/bin/ksh
print "this is $0"

# This script is run after refreshing the UASS database
# UASS specific passwords are recreated
# Schema ASSUROL_SEC is reloaded
# Table assurol.t_parametres is reloaded
# Database statistics are recomputed

export ORACLE_SID=UASS
export ORACLE_HOME=/oracle/product/12.1

connect='/ as sysdba'

$ORACLE_HOME/bin/sqlplus -s $connect <<!
shutdown immediate;
startup mount;
alter database noarchivelog;
alter database open;
!

# restore schemas passwords
$ORACLE_HOME/bin/sqlplus -s $connect <<!
@savepwdUASS.cmd
exit
!

# Create directory DUP_PUMP_DIR
$ORACLE_HOME/bin/sqlplus -s $connect <<!
drop directory DUP_PUMP_DIR;
create directory DUP_PUMP_DIR as '/oracle/oradata/dupdump';
grant read,write on directory DUP_PUMP_DIR to public
!

# Existing ASSUROL_SEC schema is dropped and recreated with dump created before db duplication
$ORACLE_HOME/bin/sqlplus -s $connect <<!
set timing on
drop user ASSUROL_SEC cascade;
exit;
!
$ORACLE_HOME/bin/impdp \"$connect\" directory=DUP_PUMP_DIR \
                                    dumpfile=UASS_ASSUROL_SEC.dmp \
                                    LOGfile=impUASS_ASSUROL_SEC.txt \
                                    schemas=ASSUROL_SEC \
                                    logtime=all

# Parameter table is reloaded
$ORACLE_HOME/bin/impdp \"$connect\" directory=DUP_PUMP_DIR \
                                    dumpfile=UASS_ASSUROL_t_parametres.dmp \
                                    logfile=impUASS_ASSUROL_t_parametres.txt \
                                    tables=assurol.t_parametres \
                                    TABLE_EXISTS_ACTION=truncate \
                                    logtime=all

# Statistics are recomputed for the whole database
$ORACLE_HOME/bin/sqlplus -s $connect <<!
set timing on
execute dbms_stats.gather_database_stats(estimate_percent => 100, degree=> 8, cascade=> true, options=>'GATHER AUTO');
exit;
!
