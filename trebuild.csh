#!/bin/csh
# Full rebuild of TelegraphCQ with database wipe.
#
# To use, type "source trebuild.csh
#
# HACK ALERT: Due to an apparent bug/feature in GNU Make 3.79.1, we need to go
# into src/backend and do a make before we can successfully perform a top-level
# make.  See indented lines below.
#
# Assumes that $PGDATA, $PGRSHOME, and $PG_SRC_ROOT are set.
set makeprog = $HOME/config/pretty_make.pl

pg_ctl stop -m fast
rm -rf $PGDATA/*
rm -rf $PGRSHOME
pushd $PG_SRC_ROOT
$makeprog -j 10 distclean
source configure-sk
    pushd src/backend
    $makeprog -j 2
    mv pm.log $PG_SRC_ROOT
    popd
$makeprog -j 2
mv pm.log build.log
$makeprog install
mv pm.log install.log
pushd src/test/examples/teststream
$makeprog
$makeprog install
popd
chdir src/test/examples/geoserver/wrapper
$makeprog
$makeprog install
rehash
initdb
sleep 1
# Recreate our default database instance
rehash
pg_ctl start
sleep 1
createdb $TCQ_DB
pg_ctl stop
popd 


