#!/usr/bin/ksh
this_script=$0

# This script launches refresh operations for uass databases
# to be performed before and after the database duplication 

WRKDIR=/export/home/oracle/scripts_dbdup
db=uass

cd $WRKDIR
date
time ./refresh_db.sh ./init_${db}.dup ./duplicate_db.sh ./pre_duplicate_${db}.sh ./post_duplicate_${db}.sh
date
