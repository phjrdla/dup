#!/usr/bin/ksh
this_script=$0

# This script a refresh for a database using RMAN active duplication and environment specific actions 
# to be performed before and after the database duplication 

# 1st parameter : duplication parameter file
# 2nd parameter : duplication script
# 2nd parameter : pre duplication script
# 3rd parameter : post duplication script

(( $# != 4 )) && { print "usage is $this_script dup_parm_file dup_script pre_dup_script post_dup_script"; exit; }

init_dup_file=$1
dup_script=$2
pre_dup_script=$3
post_dup_script=$4

[[ ! -f $init_dup_file ]] && { print "$init_dup_file not found"; exit; }

[[ -x $pre_dup_script ]] && $pre_dup_script

[[ -x $dup_script ]] && $dup_script $init_dup_file

[[ -x $post_dup_script ]] && $post_dup_script
