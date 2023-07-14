#!/bin/bash

# Remove old log
rm /home/oracle/scripts/logs/invalid_object.log

# Mail lists
MAIL_LIST=example@outlook.com

# Source environment
OUTPUT_LOC=/tmp
rm $OUTPUT_LOC/tbs_mon.out
DB_LIST=`egrep -i ":Y|:N" /etc/oratab | cut -d":" -f1 | grep -v "\#" | grep -v "\*"|grep -v ASM`
for DB in $DB_LIST ; do
echo "HOST: `hostname`  DB Name: $DB" > $OUTPUT_LOC/tbs_mon.out
export ORACLE_SID=$DB
export ORACLE_HOME=`egrep -i ":Y|:N" /etc/oratab |grep $ORACLE_SID| cut -d":" -f2 | grep -v "\#" | grep -v "\*"`
export PATH=$ORACLE_HOME/bin:$PATH

# Getting DB_NAME:
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S /nolog <<"EOF"
connect / as sysdba
set pages 0 feedback off;
prompt
select pdb_name from dba_pdbs where pdb_name != 'PDB$SEED';
exit;
EOF
)

# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo $VAL1| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "$DB_NAME_UPPER" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# Getting the invalid count
sqlplus -S /nolog <<"EOF1"
connect / as sysdba
column pdb_name new_value pdb
select pdb_name from dba_pdbs where pdb_name != 'PDB$SEED';
alter session set container = &pdb;
spool /home/oracle/scripts/logs/invalid_object.log
set echo on
set serveroutput on
set head on
set feed on
col OWNER for a30
col OBJECT_NAME for a50
col OBJECT_TYPE for a30
SELECT COUNT(*) FROM DBA_OBJECTS WHERE STATUS='INVALID';
SELECT OWNER,OBJECT_NAME,OBJECT_TYPE,STATUS FROM DBA_OBJECTS WHERE STATUS='INVALID' ORDER BY OWNER,OBJECT_TYPE,OBJECT_NAME;
exit
EOF1

# Sending mail
mailx -s "Invalid Objects of the $DB_NAME_UPPER" $MAIL_LIST < /home/oracle/scripts/logs/invalid_object.log
done
