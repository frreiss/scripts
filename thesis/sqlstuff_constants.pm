################################################################################
# sql_constants.pm
#
# Module containing useful constants for sqlstuff.pm
################################################################################

use strict;
use warnings;

package sqlstuff_constants;

# Stuff copied from the perlmod man pages.
BEGIN {
    use Exporter   ();
    our (@ISA, @EXPORT);

    @ISA         = qw(Exporter);
    @EXPORT      = qw( 
                        $DBNAME
                        $USERNAME
                        $PG_LOGFILE
                        $STP
                        $SNE
                        $STQE
                        $STQ
                        $PGRSHOME
                        $PSQL
                        $PSQL_COMMAND
                        $SQL_TMP_FILE 
                        $WRAPCH_PORTNO
                        $WRAPCH_HOST
                        $REALLY_BIG_NUMBER
                    );
}


# How to connect to the database.
our $DBNAME = "demo";
our $USERNAME = $ENV{"USER"};

# How to run postgresql
our $PG_LOGFILE = "/tmp/logfile";
our $STP = "pg_ctl stop 1>&2";
our $SNE = "pg_ctl start -l $PG_LOGFILE 1>&2";
our $STQE = "pg_ctl start -l $PG_LOGFILE -o \"-t $DBNAME -u $USERNAME -G\" 1>&2";
# (Start TelegraphCQ - without eddies):
our $STQ  = "pg_ctl start -l $PG_LOGFILE -o \"-t $DBNAME -u $USERNAME\" 1>&2";


# How to run psql
our $PGRSHOME = $ENV{"PGRSHOME"};
our $PSQL = "$PGRSHOME/bin/psql";
our $PSQL_COMMAND = "$PSQL -d $DBNAME --quiet";
our $SQL_TMP_FILE = "/tmp/runexp_sql_tmp.sql";

# Wrapper clearinghouse port
our $WRAPCH_PORTNO = 5533;
our $WRAPCH_HOST = "localhost";


# General constants...
our $REALLY_BIG_NUMBER = 1000000000;

END { }

1;

