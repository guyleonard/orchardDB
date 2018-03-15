#!/usr/bin/env perl

use strict;
use warnings;

#use Cwd;
#use Time::localtime;
use Bio::SeqIO;
use Bio::SeqIO::fasta;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use v5.10;

use Data::Dumper;

my $VERSION = "OrchardDB v1.0\n--plant.pl v0.1";

# things
#my $work_dir = cwd();

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
##        MAIN        ##
########################

foreach my $file_path (@fasta_input) {

    my $abs_path = File::Spec->rel2abs($file_path);
    my @part = split( /\//, $file_path );

    my $source    = $part[1];
    my $subsource = $part[1];
    my $filename  = $part[2];
    if ( $source ne "NCBI" ) {
        $subsource = $part[2];
        $filename  = $part[3];
    }

    # some files may be gziped, we need to use a different input
    # for those and we need absolute path for output
    my ( $name, $path, $suffix ) = fileparse( $abs_path, '.gz' );

    if ( $suffix eq ".gz" ) {
        say "Unzipping $file_path";
        my $status = gunzip "$abs_path" => "$path\/$name"
            or die "gunzip failed: $GunzipError\n";
        $file_path =~ s/\.gz//;
    }
    
    say "Reading $file_path";
    my $seqio_object = Bio::SeqIO->new(
        -file   => "$file_path",
        -format => 'fasta'
    );

    process_fasta( $seqio_object, $path, $output_fasta_dir, $filename );

    # gzip

}

########################
##        SUBS        ##
########################

# takes the  bioperl seqio object, along with
#
sub process_fasta {
    my ( $seqio_object, $abs_path, $output_fasta_dir, $filename ) = @_;

    my ( $dir, $source ) = split( $input_fasta_dir, $abs_path );
    my $current_out = "$dir\/$output_fasta_dir";

    # make the output directory
    if ( !-d $current_out ) { make_path($current_out) }

    ###
    # This will come from the input filename list soon...
    my ( $name, $path, $suffix ) = fileparse( $filename, '\.*' );
    say "Output: $current_out\/$name\.fasta";
    ###

    my $output = Bio::SeqIO->new(
        -file   => ">$current_out\/$name\.fasta",
        -format => 'fasta'
    );

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . " " . $seq->desc;
        my $sequence        = $seq->seq;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);
        $seq->id("$hashed_accession");

        # remove non-useful phylogenetic information from sequence data
        # stop codons at the end of the sequence
        $sequence =~ s/\*$//;

        # replace with X if not a valid protein code
        $sequence =~ s/[^A-z|^\-]/X/g;
        $seq->seq("$sequence");

        $output->write_seq($seq);
    }
}

sub process_JGI {

}

sub get_genome_files {
    my $input_fasta_dir = shift;
    my @fasta_files;
    my $file_finder = sub {
        return if !-f;
        return if !/\.fa|\.fasta|\.fas|\.aa|\.gz\z/;
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
