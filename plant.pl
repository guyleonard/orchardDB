#!/usr/bin/env perl

use strict;
use warnings;

#use Cwd;
#use File::Basename;
#use Time::localtime;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use Getopt::Long;    #::Complete;

use Data::Dumper;

my $VERSION = "OrchardDB v1.0 -- plant.pl v0.1";

# directories
my $input_fasta_dir;     # original FASTA format protein directory
my $output_fasta_dir;    # modified FASTA format protein directory
my $taxadb_dir;          # location of the NCBI taxadb files

# database access
my $ip_address;
my $dsn = "dbi:mysql:orchardDB:$ip_address";
my $user;
my $password;
my $table_name;

my $usage = "";

unless (@ARGV) {
    die "$usage\n";
}

########################
##        SUBS        ##
########################

sub setup_mysql_db {

    my ( $dsn, $user, $password, $table_name ) = @_;

    # connect to MySQL database
    my %attr = ( PrintError => 0, RaiseError => 1 );
    my $dbh = DBI->connect( $dsn, $user, $password, \%attr );

    my $create_table = (
        "CREATE TABLE $table_name (
  protein_ID varchar(20) NOT NULL DEFAULT '',
  accession varchar(20) DEFAULT NULL,
  species varchar(200) DEFAULT NULL,
  sequence text,
  gr_superkingdom varchar(50) DEFAULT NULL,
  gr_kingdom varchar(50) DEFAULT NULL,
  gr_phylum varchar(50) DEFAULT NULL,
  gr_class varchar(50) DEFAULT NULL,
  gr_order varchar(50) DEFAULT NULL,
  gr_family varchar(50) DEFAULT NULL,
  gr_special1 varchar(50) DEFAULT NULL,
  gr varchar(50) DEFAULT NULL,
  date_added datetime DEFAULT NULL,
  source text,
  source_ID varchar(20) DEFAULT NULL,
  gr_subkingdom varchar(50) DEFAULT NULL,
  gr_subphylum varchar(50) DEFAULT NULL,
  PRIMARY KEY (protein_ID)
  ) ENGINE=InnoDB;"
    );

    $dbh->do($create_table);

    say "$table_name was created successfully!";

    # disconnect from the MySQL database
    $dbh->disconnect();
}

sub hash_header {
    my $header = shift;
    $header = md5_hex($header);
    return $header;
}
