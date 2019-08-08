#!/usr/bin/ksh
this_script=$0

# This scripts performs all the steps necessary for an RMAN active database duplication
# Main steps are cleanup,
# generation of auxiliary instance init parameter file
# generation of rman database duplication script
# Auxliliary instance startup
# Database duplication

(( $# != 1 )) && { print "Usage is $this_script duplication_parameter_file"; exit; }

# Checks on parameter file
init_dup_file=$1
[[ ! -f $1 ]] && { print "$init_dup_file not found", exit; }
[[ ! -x $1 ]] && { print "$init_dup_file must be executable", exit; }


########################## Main ###############################################
#DEBUG=echo
DEBUG=''
grace_delay='5'

if [[ $DEBUG == '' ]]
then
   print 'scrip runs in LIVE mode, 15 sec to abort'
elif [[ $DEBUG == 'echo'  ]]
then
   print 'script runs in DEBUG mode'
else
   print "Mode $DEBUG inconnu, exit"
   exit
fi
print "Grace delay of $grace_delay secs to kill script"
sleep $grace_delay

# execute parameter file to set duplication variables
. $init_dup_file

[[ ! -d $TMPDIR ]] && { print "Folder $TMPDIR not found, exit."; exit; }

# Folders and parameters linked to destination database
passwordfile="$ORACLE_HOME/dbs/orapw${DestSid}"
spfile="$ORACLE_HOME/dbs/spfile${DestSid}.ora"

# connection string
cnxsys='/ as sysdba'

# Parameters must not be null
[[ ${SourceSid:="KO"}      == "KO" ]]  && { print "SourceSid is null, exit."; exit; }
[[ ${SourceSidPwd:="KO"}   == "KO" ]]  && { print "SourceSidPwd is null, exit."; exit; }
[[ ${DestSid:="KO"}        == "KO" ]]  && { print "DestSid is null, exit."; exit; }

# Abort instance $DestSid if found
(( instanceUp = $(ps -ef | grep pmon_$DestSid | grep -v grep | wc -l ) ))
if (( instanceUp == 1 ))
then
  print "About to abort instance $DestSid"
  # Abort auxiliary instance
  if [[ $DEBUG  == '' ]]
  then
    $ORACLE_HOME/bin/sqlplus -s $cnxsys <<!
shutdown abort
exit
!
  fi
fi

# Cleanup
print 'Files cleanup'
[[ -d $oracle_oradata/$DestSid ]]        && find $oracle_oradata/$DestSid -type f -exec ls -l {} \;
[[ -d $oracle_oradata/$DestSid ]]        && { $DEBUG find $oracle_oradata/$DestSid -type f -exec rm {} \;; print 'removed'; }
[[ -d $oracle_flash_recovery/$DestSid ]] && find $oracle_flash_recovery/$DestSid -type f -exec ls -l {} \;
[[ -d $oracle_flash_recovery/$DestSid ]] && { $DEBUG find $oracle_flash_recovery/$DestSid -type f -exec rm {} \;; print 'removed'; }
[[ -d $oracle_admin/$DestSid ]]          && find $oracle_admin/$DestSid -type f -exec ls -l {} \;
[[ -d $oracle_admin/$DestSid ]]          && { $DEBUG find $oracle_admin/$DestSid -type f -exec rm {} \;; print 'removed'; }
[[ -f $spfile ]]                         && { $DEBUG rm $spfile; print "$spfile removed"; }

# set parameters for auxiliary instance init.ora file
db_name=$DestSid
audit_file_dest="$oracle_admin/$DestSid/adump"
control_file_1='control01.ctl'
control_file_2='control02.ctl'
control_file_dir_1="$oracle_oradata/$DestSid/controlfile"
control_file_dir_2="$oracle_flash_recovery/$DestSid/controlfile"
# Fully qualified control filenames
ctl_file_1="$control_file_dir_1/$control_file_1"
ctl_file_2="$control_file_dir_2/$control_file_2"
control_files="$ctl_file_1,$ctl_file_2"
db_create_file_dest=$oracle_oradata
db_recovery_file_dest=$oracle_flash_recovery
db_recovery_file_dest_size=$recovery_file_dest_size
remote_login_passwordfile='EXCLUSIVE'

# process number, to name files uniquely 
pid=$$

# Create auxiliary instance init.ora file
init_ora_file="$TMPDIR/init_${DestSid}_4_dup_${pid}.ora"
cat <<! > $init_ora_file
db_name='$db_name'
audit_file_dest='$audit_file_dest'
control_files='$control_files'
db_create_file_dest='$db_create_file_dest'
db_recovery_file_dest='$db_recovery_file_dest'
db_recovery_file_dest_size='$db_recovery_file_dest_size'
remote_login_passwordfile='EXCLUSIVE'
!

# Create RMAN command file
rman_cmd_file="$TMPDIR/duplicate_${SourceSid}_2_${DestSid}_pull_${pid}.rman"
rman_log_file="$TMPDIR/duplicate_${SourceSid}_2_${DestSid}_pull_${pid}.log"
cat <<! > $rman_cmd_file
connect target sys/$SourceSidPwd@$SourceSid
connect auxiliary sys/$SourceSidPwd@$DestSid
run{
allocate channel prmy1 type disk;
allocate channel prmy2 type disk;
allocate channel prmy3 type disk;
allocate channel prmy4 type disk;
allocate channel prmy5 type disk;
allocate channel prmy6 type disk;
allocate auxiliary channel aux1 type disk;
allocate auxiliary channel aux2 type disk;
allocate auxiliary channel aux3 type disk;
allocate auxiliary channel aux4 type disk;
allocate auxiliary channel aux5 type disk;
allocate auxiliary channel aux6 type disk;
DUPLICATE TARGET DATABASE TO '$DestSid'
FROM ACTIVE DATABASE
spfile
PARAMETER_VALUE_CONVERT
  '$SourceSid','$DestSid'
SET DB_FILE_NAME_CONVERT
  '$SourceSid','$DestSid'
SET LOG_FILE_NAME_CONVERT
  '$SourceSid','$DestSid'
USING compressed BACKUPSET SECTION SIZE 2G
NOFILENAMECHECK;
}
!

#  Checks
print "\nCheck"
print "SourceSid is $SourceSid"
print "DestSid is $DestSid"
print "db_name is $db_name"
print "passwordfile is $passwordfile"
print "spfile is $spfile"
print "audit_file_dest is $audit_file_dest"
print "ctl_file_1 is $ctl_file_1"
print "ctl_file_2 is $ctl_file_2"
print "control_files is $control_files"
print "db_create_file_dest is $db_create_file_dest"
print "db_recovery_file_dest is $db_recovery_file_dest"
print "db_recovery_file_dest_size is $db_recovery_file_dest_size"
print "init_ora_file is $init_ora_file"
print "rman_cmd_file is $rman_cmd_file"
print "\n$init_ora_file content"
cat $init_ora_file
print "\n$rman_cmd_file content"
cat $rman_cmd_file

# Create mandatory directories
[[ ! -d $audit_file_dest       ]] && $DEBUG mkdir -p $audit_file_dest
[[ ! -d $control_file_dir_1    ]] && $DEBUG mkdir -p $control_file_dir_1
[[ ! -d $control_file_dir_2    ]] && $DEBUG mkdir -p $control_file_dir_2
[[ ! -d $db_create_file_dest   ]] && $DEBUG mkdir -p $db_create_file_dest
[[ ! -d $db_recovery_file_dest ]] && $DEBUG mkdir -p $db_recovery_file_dest

# Create password file
$DEBUG orapwd file=$passwordfile password=$SourceSidPwd entries=10  force=y
[[ -f $passwordfile ]] && ls -l $passwordfile

if [[ $DEBUG == '' ]]
then
# Start auxiliary instance
  $ORACLE_HOME/bin/sqlplus -s $cnxsys <<!
startup nomount pfile='$init_ora_file';
exit
!
fi

sleep 10

# Duplicate database with rman
print "About to duplicate ...."
$DEBUG $ORACLE_HOME/bin/rman cmdfile $rman_cmd_file log=$rman_log_file

