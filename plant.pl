#!/usr/bin/env perl

use strict;
use warnings;

#use Time::localtime;
use Cwd;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Find;
use Getopt::Long;    #::Complete;
use v5.10;

use Data::Dumper;

my $VERSION = "OrchardDB v1.0\n--plant.pl v0.1";

# directories
my $input_fasta_dir;     # original FASTA format protein directory
my $output_fasta_dir;    # modified FASTA format protein directory
my $taxadb_dir;          # location of the NCBI taxadb files

# database access
my $ip_address = "";
my $dsn        = "dbi:mysql:orchardDB:$ip_address";
my $user;
my $password;
my $table_name;

unless (@ARGV) {
    help_message();
}

GetOptions(
    'in=s'      => \$input_fasta_dir,
    'out=s'     => \$output_fasta_dir,
    'ip|i=s'    => \$ip_address,
    'user|u=s'  => \$user,
    'pass|p=s'  => \$password,
    'table|t=s' => \$table_name,
    'version|v' => sub { say "$VERSION" },
    'help|h'    => sub { help_message() }
) or help_message();

my @fasta_input = get_genome_files($input_fasta_dir);


########################
##        SUBS        ##
########################

sub get_genome_files {
    my $input_fasta_dir = shift;
    my @fasta_files;
    my $file_finder = sub {
        return if !-f;
        return if !/\.fa|\.fasta|\.fas|\.gz\z/;
        push @fasta_files, $File::Find::name;
    };
    find( $file_finder, $input_fasta_dir );
    return @fasta_files;
}

# MySQL Database called OrhcardDB, tables are user named
# All DBs include these columns:
# hashed_accession = hash of the header from original file
# original_fn, new_fn = filenames for tracking
# original header
# extracted "accession", e.g. NCBI accessions
# date of inclusion
# version of gene preds if known, else 1
# source DB, e.g. NCBI, JGI_Mycocosm, JGI_Phytozome, Ensenmbl, Other, etc
# taxonomy information
# ????
sub setup_mysql_db {

    my ( $dsn, $user, $password, $table_name ) = @_;

    # connect to MySQL database
    my %attr = ( PrintError => 0, RaiseError => 1 );
    my $dbh = DBI->connect( $dsn, $user, $password, \%attr );

    my $create_table = (
        "CREATE TABLE $table_name (
  hashed_accession varchar(50) NOT NULL DEFAULT '',
  original_fn varchar(50) DEFAULT NULL,
  fixed_fn varchar(50) DEFAULT NULL,
  original_header varchar(200) DEFAULT NULL,
  extracted_accession varchar(20) DEFAULT NULL,
  date_added datetime DEFAULT NULL,
  version text,
  source text,
  taxonomy text,
  PRIMARY KEY (hashed_accession)
  ) ENGINE=InnoDB;"
    );

    $dbh->do($create_table);

    say "$table_name was created successfully!";

    # disconnect from the MySQL database
    $dbh->disconnect();
}

# The idea is that every header will be different, even across
# different taxa, but they are messy and we need a unique ID,
# hashes are perfect for this. They're not human readable, but
# we'll be converting them back to Genus species names anyway.
sub hash_header {
    my $header = shift;
    $header = md5_hex($header);
    return $header;
}

sub help_message {
    say "Help!";
    exit(1);
}
