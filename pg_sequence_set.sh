#!/bin/bash

# Quit execution on catching any error
set -e

# Constants, args and envs
GLOBAL_POSTGRES_DB=${POSTGRES_DB:="db_name"}
GLOBAL_POSTGRES_USER=${POSTGRES_USER:="db_user"}
GLOBAL_POSTGRES_PASSWORD=${POSTGRES_PASSWORD:="db_pass"}
FINAL=$1
MARGIN=10 # Safety margin

# Execute a given SQL query and return it's (rows only) results
function pgExec() {
    local queryResult=`psql -tXA -U $GLOBAL_POSTGRES_USER -d $GLOBAL_POSTGRES_DB -c "$*"`
    echo $queryResult
}

# Find next valid value, given a sequence name
function getNextFinal() {
    local table=$1
    local pKName=$2
    local lastValue=`pgExec "SELECT $pKName FROM $table GROUP BY $pKName HAVING MOD($pKName, 10) = $FINAL ORDER BY $pKName DESC LIMIT 1;"`
    if [[ -z lastValue ]] || [[ lastValue -lt 10 ]]; then
        lastValue=$FINAL
    fi
    local nextValue=$(($lastValue+10))
    ((nextValue+=$MARGIN))
    echo $nextValue
}

# Sets next valid value, given a sequence name and the result(value) of getNextFinal()
function setNextFinal() {
    local sequence=$1
    local value=$2
    local result=`pgExec "ALTER SEQUENCE $sequence INCREMENT BY 10 START WITH $value"`
    local result2=`pgExec "SELECT setval('$sequence', $value)"`
    echo "$result $sequence ----- $result2"
}

# Get all sequences of database
function getAllSequences() {
    local sequences=`pgExec "SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'"`
    echo $sequences
}

# Get all tables of database
function getAllTables() {
    local tables=`pgExec "SELECT table_name FROM information_schema.tables WHERE table_type='BASE TABLE' AND table_schema='public'"`
    echo $tables
}

# Get primaryKey column name of a given table
function getPKName() {
    local table=$1
    local pKName=`pgExec "SELECT column_name FROM information_schema.columns WHERE table_name='$table' LIMIT 1"`
    echo $pKName
}

# Build sequence name given the table and primaryKey
function getSequenceName() {
    local table=$1
    local primaryKey=$2
    echo "${table}_${primaryKey}_seq"
}

# May be main() for the not fancy people
function makeItRain() {
    local tables=`getAllTables`
    local sequences=`getAllSequences`
    for table in $tables; do
        primaryKey=`getPKName "$table"`
        sequence=`getSequenceName "$table" "$primaryKey"`
        # If sequence don't exist, skip and don't try to set it
        if [[ ! "${sequences[@]}" =~ "${sequence}" ]]; then
            continue
        fi
        nextNumber=`getNextFinal "$table" "$primaryKey"`
        setNextFinal $sequence $nextNumber
    done
}

# just make it rain
makeItRain